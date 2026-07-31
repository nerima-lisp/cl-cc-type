;;;; t/inference-forms-advanced-test.lisp — Advanced Call Policy Inference Tests
;;;;
;;;; Tests for src/inference-forms-advanced.lisp (and its
;;;; -advanced-init/-advanced-validators companions): infer-call boundary
;;;; policies for spawn, shared-ref, typed channels, actors, STM, generators,
;;;; coroutines, SIMD, mapped/conditional types, type interfaces, SMT
;;;; assertions, type plugins, program synthesis, and FFI calls.

(in-package :cl-cc-type/test)

(defun %mk-advanced-call (function-name &rest arg-forms)
  "Build an AST-CALL node invoking FUNCTION-NAME with ARG-FORMS (already-built AST args)."
  (cl-cc/ast:make-ast-call
   :func (cl-cc/ast:make-ast-var :name function-name)
   :args arg-forms))

(defun %mk-quoted (value)
  "Build an AST-QUOTE node wrapping VALUE (a static/quoted descriptor)."
  (cl-cc/ast:make-ast-quote :value value))

(it-sequential "advanced-call-spawn-enforces-send-boundary"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'spawn (cl-cc/ast:make-ast-int :value 1)))))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2201"))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'spawn (%mk-quoted '(1 2))))))

(it-sequential "advanced-call-shared-ref-enforces-sync-boundary"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'shared-ref (cl-cc/ast:make-ast-int :value 1)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-any))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'shared-ref (%mk-quoted '(1 2))))))

(it-sequential "advanced-call-arity-violation-signals-type-inference-error"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'shared-ref
                           (cl-cc/ast:make-ast-int :value 1)
                           (cl-cc/ast:make-ast-int :value 2)))))

(it-sequential "advanced-call-make-typed-channel-and-buffered-channel"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-typed-channel (%mk-quoted 'fixnum)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2202")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::channel))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-buffered-channel
                                 (%mk-quoted 'fixnum)
                                 (cl-cc/ast:make-ast-int :value 8)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2202")))

(it-sequential "advanced-call-make-actor-ref"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-actor-ref (%mk-quoted 'fixnum)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2203")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::actor-ref)))

(it-sequential "advanced-call-make-tvar"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-tvar
                                 (%mk-quoted 'fixnum)
                                 (cl-cc/ast:make-ast-int :value 0)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2204")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::stm)))

(it-sequential "advanced-call-make-generator-type-and-coroutine-type"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-generator-type (%mk-quoted 'fixnum) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2205")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::generator))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-coroutine-type
                                 (%mk-quoted 'fixnum) (%mk-quoted 'string) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2205")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::coroutine)))

(it-sequential "advanced-call-make-simd-type"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-simd-type
                                 (%mk-quoted 'fixnum)
                                 (cl-cc/ast:make-ast-int :value 4)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2206")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'simd-vector)))

(it-sequential "advanced-call-apply-mapped-type-valid-and-invalid-transform"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted 'optional)))))
    (expect (cl-cc/type:type-union-p ty) :to-be-truthy))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted 'mysterious)))))

(it-sequential "advanced-call-apply-conditional-type-then-and-else-branches"
  (let ((then-ty (cl-cc/type:infer-with-env
                  (%mk-advanced-call 'apply-conditional-type
                                      (%mk-quoted 'fixnum) (%mk-quoted 'fixnum)
                                      (%mk-quoted 'item) (%mk-quoted 'string) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-primitive-p then-ty) :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name then-ty) :to-be 'string))
  (let ((else-ty (cl-cc/type:infer-with-env
                  (%mk-advanced-call 'apply-conditional-type
                                      (%mk-quoted 'fixnum) (%mk-quoted 'symbol)
                                      (%mk-quoted 'item) (%mk-quoted 'string) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-primitive-p else-ty) :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name else-ty) :to-be 'null)))

(it-sequential "advanced-call-load-type-interface-registers-exports"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'load-type-interface
                                 (%mk-quoted 'advanced-call-test-module)
                                 (%mk-quoted '((exported-test-fn fixnum)))
                                 (%mk-quoted "fingerprint-1")))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-symbol))
  (multiple-value-bind (scheme found-p)
      (cl-cc/type:lookup-type-interface-export 'exported-test-fn)
    (declare (ignore scheme))
    (expect found-p :to-be-truthy)))

(it-sequential "advanced-call-smt-assert-uses-registered-solver"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'smt-assert
                                 (%mk-quoted '(> x 0))
                                 (%mk-quoted 'z3)
                                 (%mk-quoted 'lia)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-bool)))

(it-sequential "advanced-call-run-type-plugin-uses-registered-hook"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'run-type-plugin (%mk-quoted 'nat-normalise) (%mk-quoted 'solve)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-any)))

(it-sequential "advanced-call-synthesize-program-uses-registered-strategy"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'synthesize-program
                                 (%mk-quoted '(-> fixnum fixnum))
                                 (%mk-quoted 'enumerative)
                                 (cl-cc/ast:make-ast-int :value 4)))))
    (expect (cl-cc/type:type-arrow-p ty) :to-be-truthy)))

(it-sequential "advanced-call-make-api-type"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-api-type
                                 (%mk-quoted :get)
                                 (%mk-quoted "/users")
                                 (%mk-quoted nil)
                                 (%mk-quoted 'string)))))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-3305")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::api-type)))

(it-sequential "advanced-call-foreign-call-validates-ffi-descriptor"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'foreign-call
                                 (%mk-quoted '(foreign strlen (c-int) c-int))
                                 (cl-cc/ast:make-ast-int :value 3)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-int))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'foreign-call
                           (%mk-quoted '(foreign strlen (c-int) c-int))
                           (%mk-quoted "not-an-int")))))

(it-sequential "advanced-call-foreign-call-accepts-a-bare-scalar-descriptor"
  ;; %VALIDATE-ADVANCED-FFI-CALL's DESCRIPTOR is not always a (FOREIGN name
  ;; args return) function form: a bare scalar descriptor like C-INT is
  ;; treated as a single-argument, TYPE-ANY-returning call instead. The
  ;; pre-existing test only ever drives the function-descriptor shape.
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'foreign-call
                                 (%mk-quoted 'c-int)
                                 (cl-cc/ast:make-ast-int :value 3)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-any)))

(it-sequential "advanced-call-foreign-call-rejects-a-runtime-arity-mismatch"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'foreign-call
                           (%mk-quoted '(foreign strlen (c-int) c-int))
                           (cl-cc/ast:make-ast-int :value 3)
                           (cl-cc/ast:make-ast-int :value 4)))))

;;; ─── %advanced-call-require-arity: min-args-only branch (no :exact-args) ──

(it-sequential "advanced-call-spawn-arity-violation-min-args-branch"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env (%mk-advanced-call 'spawn))))

;;; ─── %advanced-call-function-name: bare-symbol and unresolvable-func arms ──

(it-sequential "advanced-call-function-name-bare-symbol-and-unresolvable-func"
  (let ((ty (cl-cc/type:infer-with-env
             (cl-cc/ast:make-ast-call
              :func 'spawn
              :args (list (cl-cc/ast:make-ast-int :value 1))))))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (cl-cc/ast:make-ast-call
        :func (cl-cc/ast:make-ast-int :value 1)
        :args nil))))

;;; ─── %advanced-call-name-key: non-symbol FUNCTION-NAME arm ────────────────

(it-sequential "advanced-call-lookup-policy-rejects-non-symbol-name"
  (expect (cl-cc/type:lookup-advanced-call-policy "not-a-symbol") :to-be-null))

;;; ─── %advanced-call-quoted-arg: neither ast-quote nor ast-int arm ─────────

(it-sequential "advanced-call-quoted-arg-rejects-non-quote-non-int-argument"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'make-generator-type
                           (cl-cc/ast:make-ast-lambda
                            :params '(x)
                            :body (list (cl-cc/ast:make-ast-int :value 1)))
                           (%mk-quoted 'null)))))

;;; ─── %advanced-call-type-designator: type-arrow-p arm ─────────────────────

(it-sequential "advanced-call-spawn-rejects-function-values-arrow-designator"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'spawn
                           (cl-cc/ast:make-ast-lambda
                            :params '(x)
                            :body (list (cl-cc/ast:make-ast-int :value 1)))))))

;;; ─── %advanced-call-symbol-keyword: keywordp / stringp / fallback arms ────

(it-sequential "advanced-call-apply-mapped-type-symbol-keyword-branches"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted :optional)))))
    (expect (cl-cc/type:type-union-p ty) :to-be-truthy))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted "optional")))))
    (expect (cl-cc/type:type-union-p ty) :to-be-truthy))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted 42)))))

;;; ─── %advanced-call-optional-type: already-nullable-union short-circuit ──

(it-sequential "advanced-call-apply-mapped-type-optional-on-already-nullable-union"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type
                                 (%mk-quoted '(or null fixnum))
                                 (%mk-quoted :optional)))))
    (expect (cl-cc/type:type-union-p ty) :to-be-truthy)
    (expect (= (length (cl-cc/type:type-union-types ty)) 2) :to-be-truthy)))

;;; ─── %advanced-call-map-record-fields: record-p and non-record-p arms,
;;;     plus the :non-nullable / :partial transform arms ───────────────────

(it-sequential "advanced-call-apply-mapped-type-non-nullable-and-partial-transforms"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type
                                 (%mk-quoted 'fixnum)
                                 (%mk-quoted :non-nullable)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-int))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type
                                 (%mk-quoted '(record (a fixnum) (b string)))
                                 (%mk-quoted :partial)))))
    (expect (cl-cc/type:type-record-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-union-p (cdr (first (cl-cc/type:type-record-fields ty))))
            :to-be-truthy)))

;;; ─── %advanced-call-apply-mapped-transform: :readonly and :record arms ────

(it-sequential "advanced-call-apply-mapped-type-readonly-and-record-transforms"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted :readonly)))))
    (expect (cl-cc/type:type-capability-p ty) :to-be-truthy)
    (expect (string= (symbol-name (cl-cc/type:type-capability-cap ty)) "READONLY") :to-be-truthy))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted :record)))))
    (expect (cl-cc/type:type-record-p ty) :to-be-truthy)
    (expect (string= (symbol-name (car (first (cl-cc/type:type-record-fields ty)))) "VALUE")
            :to-be-truthy))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type
                                 (%mk-quoted '(record (a fixnum)))
                                 (%mk-quoted :record)))))
    (expect (cl-cc/type:type-record-p ty) :to-be-truthy)
    (expect (= (length (cl-cc/type:type-record-fields ty)) 1) :to-be-truthy)))

;;; ─── %advanced-call-parse-type-form: handler-case error arm ───────────────

(it-sequential "advanced-call-apply-mapped-type-malformed-base-signals-error"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'apply-mapped-type (%mk-quoted '(1 2 3)) (%mk-quoted :optional)))))

;;; ─── %advanced-call-parse-type-form: pre-built type-node passthrough arm ──
;;; Unreachable via any public advanced-call path (AST quoted values are
;;; always raw Lisp data, never already-built type-node instances), so it is
;;; exercised directly, matching this suite's existing precedent of calling
;;; internal cl-cc/type:: symbols (see t/typeclass-test.lisp).

(it-sequential "advanced-call-parse-type-form-passthrough-for-existing-type-node"
  (expect (cl-cc/type::%advanced-call-parse-type-form cl-cc/type:type-int 'test-fn) :to-be-type-equal-to cl-cc/type:type-int))

;;; ─── %advanced-call-inferred-branch-type: infer-var-match extraction arm,
;;;     %advanced-call-type-head-name's type-constructor-p arm, and
;;;     %advanced-call-type-extends-p's head-name fallback ──────────────────

(it-sequential "advanced-call-conditional-type-infer-var-match-extracts-or-falls-back"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-conditional-type
                                 (%mk-quoted '(list fixnum)) (%mk-quoted '(list fixnum))
                                 (%mk-quoted 'item) (%mk-quoted 'item) (%mk-quoted 'null)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-int))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-conditional-type
                                 (%mk-quoted 'fixnum) (%mk-quoted 'fixnum)
                                 (%mk-quoted 'item) (%mk-quoted 'item) (%mk-quoted 'null)))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-int)))

;;; ─── %advanced-call-return-value: functionp / literal-type-node arms
;;;     (the symbolp+fboundp and symbolp+boundp arms are already covered by
;;;     every constructor/return-type test above) ────────────────────────
;;; Real +advanced-call-policy-specs+ only ever store bare symbols as
;;; :return-type, so these two arms are only reachable by registering a
;;; test-only policy directly, via the same private-constructor route
;;; %initialize-advanced-call-policy-registry itself uses. The trailing
;;; "(t type-any)" clause is dead code: the only falsy Lisp value is NIL,
;;; and NIL is itself a self-evaluating symbol (symbolp/boundp both T), so
;;; a NIL :return-type is always intercepted by the symbolp+boundp clause
;;; first (returning NIL, not type-any) -- confirmed empirically, not just
;;; reasoned: an earlier version of this test asserted the type-any
;;; fallback for a NIL :return-type and failed with actual=NIL.

(it-sequential "advanced-call-return-value-functionp-and-literal-type-node-arms"
  (cl-cc/type:register-advanced-call-policy
   (cl-cc/type::%make-advanced-call-policy-from-spec
    (list '%test-advanced-return-functionp
          :exact-args 0
          :return-type (lambda (ast arg-types)
                         (declare (ignore ast arg-types))
                         cl-cc/type:type-bool)
          :summary "test-only: functionp arm")))
  (let ((ty (cl-cc/type:infer-with-env (%mk-advanced-call '%test-advanced-return-functionp))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-bool))
  (cl-cc/type:register-advanced-call-policy
   (cl-cc/type::%make-advanced-call-policy-from-spec
    (list '%test-advanced-return-literal
          :exact-args 0
          :return-type cl-cc/type:type-int
          :summary "test-only: literal type-node arm")))
  (let ((ty (cl-cc/type:infer-with-env (%mk-advanced-call '%test-advanced-return-literal))))
    (expect ty :to-be-type-equal-to cl-cc/type:type-int)))

;;; ─── %advanced-call-same-symbol-name-p: non-symbol arguments ──────────────
;;; apply-conditional-type's THEN/ELSE-branch tests above only ever compare
;;; two genuine symbols; a non-symbol comparand (legal input to this
;;; internal helper even if no current caller produces one from quoted
;;; conditional-type forms) had never made either SYMBOLP conjunct false.

(it-sequential "advanced-call-same-symbol-name-p-rejects-non-symbol-arguments"
  (expect (cl-cc/type::%advanced-call-same-symbol-name-p 42 'item) :to-be-falsy)
  (expect (cl-cc/type::%advanced-call-same-symbol-name-p 'item 42) :to-be-falsy))

;;; ─── %advanced-call-type-arg: inferred-arg-types fallback arm ─────────────

(it-sequential "advanced-call-type-arg-falls-back-to-inferred-arg-type"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-typed-channel (cl-cc/ast:make-ast-int :value 5)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2202")))

;;; ─── check-qualified-constraints: not-qualified guard, each UNLESS-disjunct
;;;     skip arm, and the final signalled-error arm ──────────────────────────

(it-sequential "check-qualified-constraints-skip-and-error-branches"
  ;; FUNC-TYPE isn't type-qualified: the top-level WHEN is false, no-op.
  (cl-cc/type:check-qualified-constraints cl-cc/type:type-int nil (cl-cc/type:type-env-empty))
  ;; type-unknown-p TYPE-ARG: satisfied via the first UNLESS disjunct.
  (cl-cc/type:check-qualified-constraints
   (cl-cc/type:make-type-qualified
    :constraints (list (cl-cc/type:make-type-constraint
                        :class-name 'qc-test-unknown
                        :type-arg cl-cc/type:+type-unknown+))
    :body cl-cc/type:type-int)
   nil (cl-cc/type:type-env-empty))
  ;; type-var-p TYPE-ARG: satisfied via the second UNLESS disjunct.
  (cl-cc/type:check-qualified-constraints
   (cl-cc/type:make-type-qualified
    :constraints (list (cl-cc/type:make-type-constraint
                        :class-name 'qc-test-var
                        :type-arg (cl-cc/type:fresh-type-var :name "a")))
    :body cl-cc/type:type-int)
   nil (cl-cc/type:type-env-empty))
  ;; DICT-ENV-LOOKUP succeeds: satisfied via the third UNLESS disjunct
  ;; (ENV is a genuine type-env, so TYPE-ENV-P is true).
  (let ((env (cl-cc/type:dict-env-extend 'qc-test-dict cl-cc/type:type-int
                                         '((method-a . :impl-a))
                                         (cl-cc/type:type-env-empty))))
    (cl-cc/type:check-qualified-constraints
     (cl-cc/type:make-type-qualified
      :constraints (list (cl-cc/type:make-type-constraint
                          :class-name 'qc-test-dict
                          :type-arg cl-cc/type:type-int))
      :body cl-cc/type:type-int)
     nil env))
  ;; ENV is not a type-env: TYPE-ENV-P is false, so the third disjunct's AND
  ;; short-circuits without calling DICT-ENV-LOOKUP; HAS-TYPECLASS-INSTANCE-P
  ;; (the fourth disjunct) is what actually satisfies the UNLESS here.
  (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (cl-cc/type:register-typeclass-instance 'qc-test-instance cl-cc/type:type-int nil)
    (cl-cc/type:check-qualified-constraints
     (cl-cc/type:make-type-qualified
      :constraints (list (cl-cc/type:make-type-constraint
                          :class-name 'qc-test-instance
                          :type-arg cl-cc/type:type-int))
      :body cl-cc/type:type-int)
     nil nil))
  ;; No disjunct is satisfied: the UNLESS body runs and signals.
  (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (signals cl-cc/type:type-inference-error
        (cl-cc/type:check-qualified-constraints
         (cl-cc/type:make-type-qualified
          :constraints (list (cl-cc/type:make-type-constraint
                              :class-name 'qc-test-missing
                              :type-arg cl-cc/type:type-string))
          :body cl-cc/type:type-int)
         nil (cl-cc/type:type-env-empty)))))

;;; ─── %advanced-call-type-designator: remaining type-shape arms ────────────
;;; Only TYPE-ARROW-P is driven via the public SPAWN path above, since a
;;; lambda AST argument is the natural way to produce an arrow type; the
;;; other seven COND clauses need type-node fixtures not easily reachable
;;; that way, so they are exercised directly.

(it-sequential "advanced-call-type-designator-covers-every-remaining-type-shape"
  (expect (cl-cc/type::%advanced-call-type-designator cl-cc/type:type-int) :to-be 'fixnum)
  (expect (cl-cc/type::%advanced-call-type-designator
           (cl-cc/type:make-type-product :elems (list cl-cc/type:type-int)))
          :to-be 'cons)
  (expect (cl-cc/type::%advanced-call-type-designator
           (cl-cc/type:make-type-record :fields nil :row-var nil))
          :to-be 'cons)
  (expect (cl-cc/type::%advanced-call-type-designator
           (cl-cc/type:make-type-variant :cases nil :row-var nil))
          :to-be 'cons)
  (expect (cl-cc/type::%advanced-call-type-designator
           (cl-cc/type:make-type-union (list cl-cc/type:type-int cl-cc/type:type-string)))
          :to-be 'union)
  (expect (cl-cc/type::%advanced-call-type-designator
           (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int)))
          :to-be 'vector)
  (expect (cl-cc/type::%advanced-call-type-designator
           (cl-cc/type:make-channel-type cl-cc/type:type-int))
          :to-be 'cl-cc/type::channel)
  (expect (cl-cc/type::%advanced-call-type-designator cl-cc/type:+type-unknown+) :to-be-null)
  (expect (cl-cc/type::%advanced-call-type-designator 42) :to-be-null))

;;; ─── %advanced-call-symbol-keyword: the fallback arm ───────────────────────
;;; keywordp/symbolp/stringp are each driven via apply-mapped-type above; a
;;; value that is none of the three (reaching the final (T VALUE) clause)
;;; is not, since every mapped-type transform in
;;; %advanced-call-apply-mapped-transform's CASE is compared with EQL, so
;;; only a symbol/keyword ever plausibly matches one of its clauses.

(it-sequential "advanced-call-symbol-keyword-fallback-for-a-non-symbolic-value"
  (expect (cl-cc/type::%advanced-call-symbol-keyword 42) :to-equal 42))

;;; ─── %advanced-call-apply-mapped-transform: the OTHERWISE arm ─────────────

(it-sequential "advanced-call-apply-mapped-transform-signals-on-an-unrecognized-transform"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type::%advanced-call-apply-mapped-transform
       cl-cc/type:type-int 'not-a-real-transform 'test-fn)))

;;; ─── %advanced-call-type-head-name: type-constructor-p and fallback arms ──
;;; The TYPE-PRIMITIVE-P arm is driven via %advanced-call-type-extends-p's
;;; callers above; TYPE-CONSTRUCTOR-P and the (T NIL) fallback are not.

(it-sequential "advanced-call-type-head-name-covers-constructor-and-fallback-arms"
  (expect (cl-cc/type::%advanced-call-type-head-name
           (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int)))
          :to-be 'vector)
  (expect (cl-cc/type::%advanced-call-type-head-name
           (cl-cc/type:make-type-union (list cl-cc/type:type-int cl-cc/type:type-string)))
          :to-be-null))

;;; ─── %advanced-call-type-arg: the missing-argument error arm ──────────────
;;; The pre-existing test only drives the ARG-TYPES fallback success path
;;; (an AST arg present but not an AST-QUOTE); reaching INDEX past both the
;;; AST's own argument list and ARG-TYPES needs an empty call.

(it-sequential "advanced-call-type-arg-signals-when-the-argument-is-entirely-missing"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type::%advanced-call-type-arg
       (cl-cc/ast:make-ast-call :func (cl-cc/ast:make-ast-var :name 'test-fn) :args nil)
       nil 0 'test-fn)))
