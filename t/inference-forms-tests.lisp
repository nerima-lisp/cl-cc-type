;;;; t/inference-forms-tests.lisp — Type Inference AST Form Tests
;;;;
;;;; Tests for infer() on concrete AST node types: ast-quote, ast-the, typed
;;;; holes, ast-setq, ast-block, ast-defun/defvar, ast-function,
;;;; lambda-param-env, ast-flet/ast-labels, plus the FR-15xx/22xx/24xx/30xx/33xx
;;;; advanced-call integration surface.
;;;;
;;;; Ported from the cl-cc monorepo's
;;;; tests/unit/type/inference-forms-tests.lisp. `cl-cc:lower-sexp-to-ast`
;;;; becomes `cl-cc/parse:lower-sexp-to-ast` now that cl-cc-parse has its own
;;;; standalone repository.

(in-package :cl-cc-type/test)

;;; ─── infer: ast-quote edge cases ──────────────────────────────────────────
;;;
;;; Not an it-each: cl-weave's it-each destructuring-binds each case tuple
;;; from a literal, unevaluated data list, so a bare symbol like type-string
;;; would bind to the SYMBOL TYPE-STRING rather than the type-string value —
;;; comparing against it via :to-be-type-equal-to would silently exercise the
;;; wrong thing. Two it-sequential tests instead.

(it-sequential "infer-quote-literal-types-string"
  ;; Quoting a string infers type-string.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(quote "hello"))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-string))))

(it-sequential "infer-quote-literal-types-cons"
  ;; Quoting a cons infers type-cons.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(quote (1 2 3)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-cons))))

;;; ─── infer: ast-the ───────────────────────────────────────────────────────

(it-sequential "infer-the-matching-type-is-fixnum"
  ;; (the fixnum 42): annotated type matches inferred type; result is fixnum.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(the fixnum 42))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-primitive-name ty) :to-be 'fixnum))))

(it-sequential "infer-the-refinement-base-is-fixnum"
  ;; (the (refine fixnum plusp) 42): refinement base resolves to fixnum.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(the (refine fixnum plusp) 42))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (let ((prim (if (type-refinement-p ty)
                       (type-refinement-base ty)
                       ty)))
        (expect (type-primitive-name prim) :to-be 'fixnum)))))

(it-sequential "infer-the-type-mismatch-signals-error"
  ;; (the string 42): annotation conflicts with inferred fixnum; signals type-mismatch-error.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(the string 42))))
    (signals type-mismatch-error (infer-with-env ast))))

(it-sequential "infer-typed-hole-signals-error"
  ;; Typed hole _ in expression signals typed-hole-error.
  (reset-type-vars!)
  (let* ((env (type-env-extend 'x (type-to-scheme type-int) (type-env-empty)))
         (ast (cl-cc/parse:lower-sexp-to-ast '(+ x _))))
    (signals typed-hole-error (infer ast env))))

(it-sequential "infer-typed-hole-message-names-in-scope-vars"
  ;; Typed hole error message includes 'Available: X ::' listing in-scope bindings.
  (reset-type-vars!)
  (let* ((env (type-env-extend 'x (type-to-scheme type-int) (type-env-empty)))
         (ast (cl-cc/parse:lower-sexp-to-ast '(+ x _))))
    (handler-case
        (infer ast env)
      (typed-hole-error (e)
        (let ((message (type-inference-error-message e)))
          (expect (search "Available: X ::" message) :to-be-truthy))))))

;;; ─── infer: ast-setq / ast-block / infer-with-constraints ───────────────

(it-sequential "infer-setq-returns-fixnum"
  ;; infer of (setq x 42) returns a fixnum type primitive.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(setq x 42))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-primitive-name ty) :to-be 'fixnum))))

(it-sequential "infer-block-returns-last-form"
  ;; infer of a block expression returns the type of its last form.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(block b 1 2 3))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-application-resolves-constraint"
  ;; infer of a self-applying lambda resolves the constraint and returns a fixnum result type.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '((lambda (x) x) 42))))
    (multiple-value-bind (ty subst residual)
        (cl-cc/type::infer-with-constraints ast (type-env-empty))
      (declare (ignore subst))
      (expect residual :to-be-null)
      (expect (type-primitive-name ty) :to-be 'fixnum))))

;;; ─── infer: ast-defun / ast-defvar ────────────────────────────────────────

(it-each (("infer-top-level-form-types defun"         (defun f (x) (+ x 1)) :function)
          ("infer-top-level-form-types defvar-init"   (defvar *x* 42)       :symbol)
          ("infer-top-level-form-types defvar-no-val" (defvar *x*)          :symbol))
    "~A"
    (name-ignored sexp expected-kind)
  (declare (ignore name-ignored))
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast sexp)))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (if (eq expected-kind :function)
          (expect (type-arrow-p ty) :to-be-truthy)
          (expect ty :to-be-type-equal-to type-symbol)))))

;;; ─── infer: ast-function ──────────────────────────────────────────────────

(it-sequential "infer-function-ref-cases-known"
  (reset-type-vars!)
  (let* ((fn-ty (make-type-arrow-raw
                 :params (list type-int) :return type-int))
         (env (type-env-extend 'f (type-to-scheme fn-ty) (type-env-empty)))
         (ast (cl-cc/parse:lower-sexp-to-ast '(function f))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy))))

(it-sequential "infer-function-ref-cases-unknown"
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(function unknown-fn-xyz))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy))))

;;; ─── %make-lambda-param-env ────────────────────────────────────────────────

(it-sequential "infer-make-lambda-param-env-empty-params"
  ;; %make-lambda-param-env with nil params returns empty type list and the same unextended env.
  (reset-type-vars!)
  (let ((empty-env (type-env-empty)))
    (multiple-value-bind (types body-env)
        (cl-cc/type::%make-lambda-param-env nil empty-env)
      (expect types :to-be-null)
      (expect (eq body-env empty-env) :to-be-truthy))))

(it-sequential "infer-make-lambda-param-env-two-params"
  ;; %make-lambda-param-env with (x y) returns two distinct type vars and extended env with x bound.
  (reset-type-vars!)
  (multiple-value-bind (types body-env)
      (cl-cc/type::%make-lambda-param-env '(x y) (type-env-empty))
    (expect (length types) :to-equal 2)
    (expect (type-var-p (first types)) :to-be-truthy)
    (expect (type-var-p (second types)) :to-be-truthy)
    (expect (eq (first types) (second types)) :to-be-falsy)
    (expect (type-env-p body-env) :to-be-truthy)
    (multiple-value-bind (scheme-x found-x) (type-env-lookup 'x body-env)
      (expect found-x :to-be-truthy)
      (expect (type-scheme-quantified-vars scheme-x) :to-be-null))))

;;; ─── infer: ast-flet / ast-labels ─────────────────────────────────────────

(it-each (("infer-local-function-forms flet"   (flet   ((f (x) (+ x 1))) (f 5)))
          ("infer-local-function-forms labels" (labels ((f (x) (+ x 1))) (f 5))))
    "~A"
    (name-ignored sexp)
  (declare (ignore name-ignored))
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast sexp)))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-primitive-name ty) :to-be 'fixnum))))

;;; ─── Advanced FR inference integration ────────────────────────────────────

(it-sequential "advanced-infer-spawn-enforces-send-and-returns-future"
  ;; FR-1502/2201: infer-call rejects non-Send spawn payloads and returns Future for valid calls.
  (reset-type-vars!)
  (let ((valid (cl-cc/parse:lower-sexp-to-ast '(spawn 1)))
        (invalid (cl-cc/parse:lower-sexp-to-ast '(spawn '(1 2)))))
    (multiple-value-bind (ty subst) (infer-with-env valid)
      (declare (ignore subst))
      (expect (type-advanced-p ty) :to-be-truthy)
      (expect (type-advanced-feature-id ty) :to-equal "FR-2201"))
    (signals type-inference-error (infer-with-env invalid))))

(it-sequential "advanced-infer-shared-ref-enforces-sync"
  ;; FR-1502: shared references reject function closures because function values are not Sync.
  (reset-type-vars!)
  (signals type-inference-error
    (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(shared-ref (lambda (x) x))))))

(it-sequential "advanced-infer-ffi-interface-smt-plugin-and-synthesis-validate-descriptors"
  ;; FR-2103/2405/2406/3002/3003 validators run from infer-call, not only parse-time metadata.
  (flet ((infer-ok (form)
           (multiple-value-bind (ty subst) (infer-with-env (cl-cc/parse:lower-sexp-to-ast form))
             (declare (ignore subst))
             (expect ty :to-be-truthy))))
    (reset-type-vars!)
    (multiple-value-bind (ty subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(foreign-call '(foreign strlen (c-string) c-int) "abc")))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(foreign-call '(foreign strlen (c-string) c-int) 1))))

    (infer-ok '(load-type-interface 'user-module '((lookup (function (fixnum) fixnum)) save) '"sha256:abc"))
    (multiple-value-bind (imported-ty imported-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast 'lookup))
      (declare (ignore imported-subst))
      (expect (type-arrow-p imported-ty) :to-be-truthy))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(load-type-interface 'user-module '(lookup lookup) '"sha256:abc"))))

    (infer-ok '(smt-assert '(< x 3) 'z3 'lia))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(smt-assert '(< x 3) 'unknown 'lia))))

    (infer-ok '(run-type-plugin 'nat-normalise 'solve))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(run-type-plugin 'nat-normalise 'emit))))

    (multiple-value-bind (synth-ty synth-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(synthesize-program '(-> integer integer) 'enumerative 8)))
      (declare (ignore synth-subst))
      (expect (type-arrow-p synth-ty) :to-be-truthy))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(synthesize-program '(-> integer integer) 'enumerative 0))))))

(it-sequential "advanced-infer-mapped-and-conditional-type-calls-run-contracts"
  ;; FR-3301/3302 mapped and conditional type evaluation calls reuse advanced contracts during inference.
  (flet ((infer-ok (form)
           (multiple-value-bind (ty subst) (infer-with-env (cl-cc/parse:lower-sexp-to-ast form))
             (declare (ignore subst))
             (expect ty :to-be-truthy))))
    (reset-type-vars!)
    (multiple-value-bind (mapped-ty mapped-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(apply-mapped-type 'fixnum 'optional)))
      (declare (ignore mapped-subst))
      (expect (type-union-p mapped-ty) :to-be-truthy)
      (expect (some (lambda (member) (type-equal-p member type-null))
                     (type-union-types mapped-ty))
              :to-be-truthy))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(apply-mapped-type '(list fixnum) 'mysterious))))

    (multiple-value-bind (conditional-ty conditional-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(apply-conditional-type '(list fixnum) 'list 'item 'item 'null)))
      (declare (ignore conditional-subst))
      (expect conditional-ty :to-be-type-equal-to type-int))
    (multiple-value-bind (else-ty else-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(apply-conditional-type 'fixnum 'list 'item 'item 'null)))
      (declare (ignore else-subst))
      (expect else-ty :to-be-type-equal-to type-null))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(apply-conditional-type '(list fixnum) 'list 'item 'item 'item))))))

(it-sequential "advanced-infer-registries-dispatch-custom-hooks"
  ;; FR-2406/3002/3003 registry hooks are actually invoked from advanced inference calls.
  (let ((smt-called nil)
        (plugin-called nil)
        (synthesis-called nil))
    (register-smt-solver 'unit-solver
                          (lambda (constraint theory)
                            (setf smt-called (list constraint theory))
                            (list :status :sat :counterexample :none)))
    (register-type-checker-plugin 'unit-plugin 'solve
                                   (lambda (ast arg-types env)
                                     (declare (ignore ast arg-types env))
                                     (setf plugin-called t)
                                     (list :status :ok :type type-string)))
    (register-type-synthesis-strategy 'unit-search
                                       (lambda (signature fuel)
                                         (setf synthesis-called (list signature fuel))
                                         (list :status :candidate :signature signature)))
    (multiple-value-bind (smt-ty smt-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(smt-assert '(< x 3) 'unit-solver 'lia)))
      (declare (ignore smt-subst))
      (expect smt-ty :to-be-type-equal-to type-bool))
    (multiple-value-bind (plugin-ty plugin-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(run-type-plugin 'unit-plugin 'solve)))
      (declare (ignore plugin-subst))
      (expect plugin-ty :to-be-type-equal-to type-string))
    (multiple-value-bind (synth-ty synth-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(synthesize-program 'fixnum 'unit-search 3)))
      (declare (ignore synth-subst))
      (expect synth-ty :to-be-type-equal-to type-int))
    (expect smt-called :to-be-truthy)
    (expect plugin-called :to-be-truthy)
    (expect synthesis-called :to-be-truthy)))

(it-sequential "advanced-infer-constructor-policies-cover-channels-actors-stm-coroutines-simd-and-routing"
  ;; FR-2202/2203/2204/2205/2206/3305 constructor helpers are intercepted by advanced call policies.
  (reset-type-vars!)
  (flet ((infer-type (form)
           (multiple-value-bind (ty subst) (infer-with-env (cl-cc/parse:lower-sexp-to-ast form))
             (declare (ignore subst))
             ty)))
    (let ((channel-ty (infer-type '(make-typed-channel 'fixnum)))
          (buffered-ty (infer-type '(make-buffered-channel 'fixnum 4)))
          (actor-ty (infer-type '(make-actor-ref 'fixnum)))
          (stm-ty (infer-type '(make-tvar 'fixnum 1)))
          (generator-ty (infer-type '(make-generator-type 'fixnum 'string)))
          (coroutine-ty (infer-type '(make-coroutine-type 'fixnum 'string 'integer)))
          (simd-ty (infer-type '(make-simd-type 'fixnum 4))))
      (expect (type-advanced-p channel-ty) :to-be-truthy)
      (expect (type-advanced-p buffered-ty) :to-be-truthy)
      (expect (type-advanced-feature-id channel-ty) :to-equal "FR-2202")
      (expect (type-advanced-feature-id buffered-ty) :to-equal "FR-2202")
      (expect (type-advanced-feature-id actor-ty) :to-equal "FR-2203")
      (expect (type-advanced-feature-id stm-ty) :to-equal "FR-2204")
      (expect (type-advanced-feature-id generator-ty) :to-equal "FR-2205")
      (expect (type-advanced-feature-id coroutine-ty) :to-equal "FR-2205")
      (expect (type-advanced-feature-id simd-ty) :to-equal "FR-2206"))
    (multiple-value-bind (api-ty api-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-api-type 'get '"/users/{id}" '((id integer)) 'user)))
      (declare (ignore api-subst))
      (expect (type-advanced-p api-ty) :to-be-truthy)
      (expect (type-advanced-feature-id api-ty) :to-equal "FR-3305"))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-buffered-channel 'fixnum))))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-typed-channel))))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-actor-ref))))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-tvar 'fixnum))))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-generator-type 'fixnum))))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-coroutine-type 'fixnum 'string))))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-simd-type 'fixnum))))
    (multiple-value-bind (api2-ty api2-subst)
        (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-api-type 'get '"/users/{id}" '((id fixnum)) 'fixnum)))
      (declare (ignore api2-subst))
      (expect (type-advanced-p api2-ty) :to-be-truthy)
      (expect (type-advanced-feature-id api2-ty) :to-equal "FR-3305"))
    (signals type-inference-error
      (infer-with-env (cl-cc/parse:lower-sexp-to-ast '(make-api-type 'get '"/users" '()))))))
