;;;; t/types-extended-registries-test.lisp — Advanced Dispatch Registries Tests
;;;;
;;;; Tests for src/types-extended-registries.lisp:
;;;; type-interface-module registration/lookup, the SMT-solver, type-checker
;;;; plugin, and type-synthesis-strategy registries built via DEFINE-REGISTRY,
;;;; their dispatch functions' "no handler registered" error paths, and the
;;;; deterministic default handler shims.

(in-package :cl-cc/type/registries/test)

(it-sequential "lookup-type-interface-returns-nil-for-an-unregistered-module"
  (expect (lookup-type-interface 'no-such-registries-test-module) :to-be nil))

(it-sequential "lookup-type-interface-export-reports-found-p-false-when-absent"
  (multiple-value-bind (scheme found-p)
      (lookup-type-interface-export 'no-such-registries-export-name)
    (expect scheme :to-be nil)
    (expect found-p :to-be-falsy)))

(it-sequential "register-smt-solver-and-lookup-smt-solver-round-trip"
  (let ((handler (lambda (constraint theory)
                    (list :status :sat :constraint constraint :theory theory))))
    (register-smt-solver 'registries-test-solver handler)
    (expect (lookup-smt-solver 'registries-test-solver) :to-be handler)
    (expect (lookup-smt-solver 'registries-no-such-solver) :to-be nil)))

(it-sequential "solve-smt-constraint-dispatches-through-the-registered-handler"
  (register-smt-solver
   'registries-dispatch-solver
   (lambda (constraint theory) (list :status :sat :constraint constraint :theory theory)))
  (let ((result (solve-smt-constraint '(> x 0) 'registries-dispatch-solver 'lia)))
    (expect (getf result :status) :to-be :sat)
    (expect (getf result :constraint) :to-equal '(> x 0))
    (expect (getf result :theory) :to-be 'lia)))

(it-sequential "solve-smt-constraint-signals-an-error-when-no-solver-is-registered"
  (signals error
      (solve-smt-constraint '(> x 0) 'registries-unregistered-solver 'lia)))

(it-sequential "%default-smt-solver-returns-a-deterministic-unknown-shim-result"
  (let ((result (%default-smt-solver '(> x 0) 'lia)))
    (expect (getf result :status) :to-be :unknown)
    (expect (getf result :constraint) :to-equal '(> x 0))
    (expect (getf result :theory) :to-be 'lia)
    (expect (getf result :counterexample) :to-be :none)))

(it-sequential "register-type-checker-plugin-and-lookup-type-checker-plugin-round-trip"
  (let ((handler (lambda (ast arg-types env)
                    (declare (ignore ast arg-types env))
                    (list :status :ok :type type-any))))
    (register-type-checker-plugin 'registries-test-plugin 'solve handler)
    (expect (lookup-type-checker-plugin 'registries-test-plugin 'solve) :to-be handler)
    (expect (lookup-type-checker-plugin 'registries-test-plugin 'rewrite) :to-be nil)
    (expect (lookup-type-checker-plugin 'registries-no-such-plugin 'solve) :to-be nil)))

(it-sequential "run-type-checker-plugin-dispatches-through-the-registered-hook"
  (register-type-checker-plugin
   'registries-dispatch-plugin 'solve
   (lambda (ast arg-types env) (list :status :ok :ast ast :arg-types arg-types :env env)))
  (let ((result (run-type-checker-plugin
                 'registries-dispatch-plugin 'solve :the-ast (list type-int) :the-env)))
    (expect (getf result :status) :to-be :ok)
    (expect (getf result :ast) :to-be :the-ast)
    (expect (getf result :env) :to-be :the-env)))

(it-sequential "run-type-checker-plugin-signals-an-error-when-no-plugin-is-registered"
  (signals error
      (run-type-checker-plugin
       'registries-unregistered-plugin 'solve :ast nil :env)))

(it-sequential "%default-type-plugin-returns-a-static-ok-result"
  (let ((result (%default-type-plugin :ast (list type-int) :env)))
    (expect (getf result :status) :to-be :ok)
    (expect (getf result :type) :to-be-type-equal-to type-any)))

(it-sequential "register-type-synthesis-strategy-and-lookup-type-synthesis-strategy-round-trip"
  (let ((handler (lambda (signature fuel) (list :status :candidate :signature signature :fuel fuel))))
    (register-type-synthesis-strategy 'registries-test-strategy handler)
    (expect (lookup-type-synthesis-strategy 'registries-test-strategy) :to-be handler)
    (expect (lookup-type-synthesis-strategy 'registries-no-such-strategy) :to-be nil)))

(it-sequential "run-type-synthesis-dispatches-through-the-registered-strategy"
  (register-type-synthesis-strategy
   'registries-dispatch-strategy
   (lambda (signature fuel) (list :status :candidate :signature signature :fuel fuel)))
  (let ((result (run-type-synthesis '(-> fixnum fixnum) 'registries-dispatch-strategy 3)))
    (expect (getf result :status) :to-be :candidate)
    (expect (getf result :signature) :to-equal '(-> fixnum fixnum))
    (expect (getf result :fuel) :to-equal 3)))

(it-sequential "run-type-synthesis-signals-an-error-when-no-strategy-is-registered"
  (signals error
      (run-type-synthesis '(-> fixnum fixnum) 'registries-unregistered-strategy 3)))

(it-sequential "%default-type-synthesis-returns-a-candidate-when-fuel-remains"
  (let ((result (%default-type-synthesis '(-> fixnum fixnum) 2)))
    (expect (getf result :status) :to-be :candidate)
    (expect (getf result :signature) :to-equal '(-> fixnum fixnum))
    (expect (getf result :fuel) :to-equal 2)
    (expect (getf result :candidate) :to-be-truthy)))

(it-sequential "%default-type-synthesis-reports-exhausted-when-fuel-is-not-positive"
  (let ((zero-fuel (%default-type-synthesis '(-> fixnum fixnum) 0)))
    (expect (getf zero-fuel :status) :to-be :exhausted)
    (expect (getf zero-fuel :candidate) :to-be nil))
  (let ((negative-fuel (%default-type-synthesis '(-> fixnum fixnum) -1)))
    (expect (getf negative-fuel :status) :to-be :exhausted)
    (expect (getf negative-fuel :candidate) :to-be nil)))

(it-sequential "%initialize-advanced-dispatch-registries-installs-the-default-handlers"
  (expect (%initialize-advanced-dispatch-registries) :to-be t)
  (expect (lookup-smt-solver 'z3) :to-be #'%default-smt-solver)
  (expect (lookup-smt-solver 'cvc5) :to-be #'%default-smt-solver)
  (expect (lookup-type-checker-plugin 'nat-normalise 'solve)
          :to-be #'%default-type-plugin)
  (expect (lookup-type-checker-plugin 'nat-normalise 'rewrite)
          :to-be #'%default-type-plugin)
  (expect (lookup-type-synthesis-strategy 'enumerative)
          :to-be #'%default-type-synthesis)
  (expect (lookup-type-synthesis-strategy 'refinement)
          :to-be #'%default-type-synthesis)
  (expect (lookup-type-synthesis-strategy 'proof-search)
          :to-be #'%default-type-synthesis))
