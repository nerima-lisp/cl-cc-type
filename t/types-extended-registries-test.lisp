;;;; t/types-extended-registries-test.lisp — Advanced Dispatch Registries Tests
;;;;
;;;; Tests for src/types-extended-registries.lisp:
;;;; type-interface-module registration/lookup, the SMT-solver, type-checker
;;;; plugin, and type-synthesis-strategy registries built via DEFINE-REGISTRY,
;;;; their dispatch functions' "no handler registered" error paths, and the
;;;; deterministic default handler shims.

(in-package :cl-cc-type/test)

(it-sequential "register-type-interface-returns-a-summary-and-lookup-type-interface-finds-it"
  (let ((summary (cl-cc/type:register-type-interface
                   'registries-test-module
                   '((registries-test-fn-a fixnum) (registries-test-fn-b))
                   "fingerprint-registries-1")))
    (expect (cl-cc/type:type-interface-module-p summary) :to-be-truthy)
    (expect (cl-cc/type:type-interface-module-name summary) :to-be 'registries-test-module)
    (expect (cl-cc/type:type-interface-module-fingerprint summary)
            :to-equal "fingerprint-registries-1")
    (expect (cl-cc/type:type-interface-module-exports summary)
            :to-equal '(registries-test-fn-a registries-test-fn-b))
    (let ((found (cl-cc/type:lookup-type-interface 'registries-test-module)))
      (expect found :to-be summary))))

(it-sequential "lookup-type-interface-returns-nil-for-an-unregistered-module"
  (expect (cl-cc/type:lookup-type-interface 'no-such-registries-test-module) :to-be nil))

(it-sequential "register-type-interface-accepts-a-string-module-name"
  (let ((summary (cl-cc/type:register-type-interface
                   "STRING-NAMED-REGISTRIES-MODULE"
                   '((registries-test-string-fn fixnum))
                   "fingerprint-registries-string")))
    (expect (cl-cc/type:type-interface-module-p summary) :to-be-truthy)
    (expect (cl-cc/type:lookup-type-interface "STRING-NAMED-REGISTRIES-MODULE") :to-be summary)))

(it-sequential "register-type-interface-handles-cons-and-bare-symbol-exports"
  ;; Exercises both branches of the internal export-name/export-type helpers:
  ;; a (name type) cons, a (name) cons with no type, and a bare symbol export.
  (let ((summary (cl-cc/type:register-type-interface
                   'registries-mixed-export-module
                   '((registries-export-typed fixnum)
                     (registries-export-untyped)
                     registries-export-bare)
                   "fingerprint-registries-mixed")))
    (expect (cl-cc/type:type-interface-module-exports summary)
            :to-equal '(registries-export-typed registries-export-untyped registries-export-bare))
    (let ((typed-entry (assoc 'registries-export-typed
                               (cl-cc/type:type-interface-module-exported-types summary))))
      (expect (cl-cc/type:type-primitive-p (cdr typed-entry)) :to-be-truthy)
      (expect (cl-cc/type:type-primitive-name (cdr typed-entry)) :to-be 'fixnum))
    (let ((untyped-entry (assoc 'registries-export-untyped
                                 (cl-cc/type:type-interface-module-exported-types summary))))
      (expect (cdr untyped-entry) :to-be-type-equal-to cl-cc/type:type-any))
    (let ((bare-entry (assoc 'registries-export-bare
                              (cl-cc/type:type-interface-module-exported-types summary))))
      (expect (cdr bare-entry) :to-be-type-equal-to cl-cc/type:type-any)))
  (multiple-value-bind (scheme found-p)
      (cl-cc/type:lookup-type-interface-export 'registries-export-bare)
    (expect found-p :to-be-truthy)
    (expect (cl-cc/type:type-scheme-p scheme) :to-be-truthy)))

(it-sequential "lookup-type-interface-export-reports-found-p-false-when-absent"
  (multiple-value-bind (scheme found-p)
      (cl-cc/type:lookup-type-interface-export 'no-such-registries-export-name)
    (expect scheme :to-be nil)
    (expect found-p :to-be-falsy)))

(it-sequential "register-smt-solver-and-lookup-smt-solver-round-trip"
  (let ((handler (lambda (constraint theory)
                    (list :status :sat :constraint constraint :theory theory))))
    (cl-cc/type:register-smt-solver 'registries-test-solver handler)
    (expect (cl-cc/type:lookup-smt-solver 'registries-test-solver) :to-be handler)
    (expect (cl-cc/type:lookup-smt-solver 'registries-no-such-solver) :to-be nil)))

(it-sequential "solve-smt-constraint-dispatches-through-the-registered-handler"
  (cl-cc/type:register-smt-solver
   'registries-dispatch-solver
   (lambda (constraint theory) (list :status :sat :constraint constraint :theory theory)))
  (let ((result (cl-cc/type:solve-smt-constraint '(> x 0) 'registries-dispatch-solver 'lia)))
    (expect (getf result :status) :to-be :sat)
    (expect (getf result :constraint) :to-equal '(> x 0))
    (expect (getf result :theory) :to-be 'lia)))

(it-sequential "solve-smt-constraint-signals-an-error-when-no-solver-is-registered"
  (signals error
      (cl-cc/type:solve-smt-constraint '(> x 0) 'registries-unregistered-solver 'lia)))

(it-sequential "%default-smt-solver-returns-a-deterministic-unknown-shim-result"
  (let ((result (cl-cc/type::%default-smt-solver '(> x 0) 'lia)))
    (expect (getf result :status) :to-be :unknown)
    (expect (getf result :constraint) :to-equal '(> x 0))
    (expect (getf result :theory) :to-be 'lia)
    (expect (getf result :counterexample) :to-be :none)))

(it-sequential "register-type-checker-plugin-and-lookup-type-checker-plugin-round-trip"
  (let ((handler (lambda (ast arg-types env)
                    (declare (ignore ast arg-types env))
                    (list :status :ok :type cl-cc/type:type-any))))
    (cl-cc/type:register-type-checker-plugin 'registries-test-plugin 'solve handler)
    (expect (cl-cc/type:lookup-type-checker-plugin 'registries-test-plugin 'solve) :to-be handler)
    (expect (cl-cc/type:lookup-type-checker-plugin 'registries-test-plugin 'rewrite) :to-be nil)
    (expect (cl-cc/type:lookup-type-checker-plugin 'registries-no-such-plugin 'solve) :to-be nil)))

(it-sequential "run-type-checker-plugin-dispatches-through-the-registered-hook"
  (cl-cc/type:register-type-checker-plugin
   'registries-dispatch-plugin 'solve
   (lambda (ast arg-types env) (list :status :ok :ast ast :arg-types arg-types :env env)))
  (let ((result (cl-cc/type:run-type-checker-plugin
                 'registries-dispatch-plugin 'solve :the-ast (list cl-cc/type:type-int) :the-env)))
    (expect (getf result :status) :to-be :ok)
    (expect (getf result :ast) :to-be :the-ast)
    (expect (getf result :env) :to-be :the-env)))

(it-sequential "run-type-checker-plugin-signals-an-error-when-no-plugin-is-registered"
  (signals error
      (cl-cc/type:run-type-checker-plugin
       'registries-unregistered-plugin 'solve :ast nil :env)))

(it-sequential "%default-type-plugin-returns-a-static-ok-result"
  (let ((result (cl-cc/type::%default-type-plugin :ast (list cl-cc/type:type-int) :env)))
    (expect (getf result :status) :to-be :ok)
    (expect (getf result :type) :to-be-type-equal-to cl-cc/type:type-any)))

(it-sequential "register-type-synthesis-strategy-and-lookup-type-synthesis-strategy-round-trip"
  (let ((handler (lambda (signature fuel) (list :status :candidate :signature signature :fuel fuel))))
    (cl-cc/type:register-type-synthesis-strategy 'registries-test-strategy handler)
    (expect (cl-cc/type:lookup-type-synthesis-strategy 'registries-test-strategy) :to-be handler)
    (expect (cl-cc/type:lookup-type-synthesis-strategy 'registries-no-such-strategy) :to-be nil)))

(it-sequential "run-type-synthesis-dispatches-through-the-registered-strategy"
  (cl-cc/type:register-type-synthesis-strategy
   'registries-dispatch-strategy
   (lambda (signature fuel) (list :status :candidate :signature signature :fuel fuel)))
  (let ((result (cl-cc/type:run-type-synthesis '(-> fixnum fixnum) 'registries-dispatch-strategy 3)))
    (expect (getf result :status) :to-be :candidate)
    (expect (getf result :signature) :to-equal '(-> fixnum fixnum))
    (expect (getf result :fuel) :to-equal 3)))

(it-sequential "run-type-synthesis-signals-an-error-when-no-strategy-is-registered"
  (signals error
      (cl-cc/type:run-type-synthesis '(-> fixnum fixnum) 'registries-unregistered-strategy 3)))

(it-sequential "%default-type-synthesis-returns-a-candidate-when-fuel-remains"
  (let ((result (cl-cc/type::%default-type-synthesis '(-> fixnum fixnum) 2)))
    (expect (getf result :status) :to-be :candidate)
    (expect (getf result :signature) :to-equal '(-> fixnum fixnum))
    (expect (getf result :fuel) :to-equal 2)
    (expect (getf result :candidate) :to-be-truthy)))

(it-sequential "%default-type-synthesis-reports-exhausted-when-fuel-is-not-positive"
  (let ((zero-fuel (cl-cc/type::%default-type-synthesis '(-> fixnum fixnum) 0)))
    (expect (getf zero-fuel :status) :to-be :exhausted)
    (expect (getf zero-fuel :candidate) :to-be nil))
  (let ((negative-fuel (cl-cc/type::%default-type-synthesis '(-> fixnum fixnum) -1)))
    (expect (getf negative-fuel :status) :to-be :exhausted)
    (expect (getf negative-fuel :candidate) :to-be nil)))

(it-sequential "%initialize-advanced-dispatch-registries-installs-the-default-handlers"
  (expect (cl-cc/type::%initialize-advanced-dispatch-registries) :to-be t)
  (expect (cl-cc/type:lookup-smt-solver 'z3) :to-be #'cl-cc/type::%default-smt-solver)
  (expect (cl-cc/type:lookup-smt-solver 'cvc5) :to-be #'cl-cc/type::%default-smt-solver)
  (expect (cl-cc/type:lookup-type-checker-plugin 'nat-normalise 'solve)
          :to-be #'cl-cc/type::%default-type-plugin)
  (expect (cl-cc/type:lookup-type-checker-plugin 'nat-normalise 'rewrite)
          :to-be #'cl-cc/type::%default-type-plugin)
  (expect (cl-cc/type:lookup-type-synthesis-strategy 'enumerative)
          :to-be #'cl-cc/type::%default-type-synthesis)
  (expect (cl-cc/type:lookup-type-synthesis-strategy 'refinement)
          :to-be #'cl-cc/type::%default-type-synthesis)
  (expect (cl-cc/type:lookup-type-synthesis-strategy 'proof-search)
          :to-be #'cl-cc/type::%default-type-synthesis))
