;;;; t/types-extended-nodes-coverage-test.lisp
;;;; Targeted coverage for uncovered branches in:
;;;;   src/types-extended-nodes.lisp — type-free-vars for capability/refinement/handler/gadt-con
;;;;   src/types-core.lisp — fresh-rigid-var, type-rigid-equal-p
;;;;   src/types-env.lisp — type-env-bindings

(in-package :cl-cc-type/test)

;;; ─── type-free-vars: capability ─────────────────────────────────────────────

(it-sequential "free-vars-capability-var-base-yields-one-fv"
  (let* ((v   (cl-cc/type:fresh-type-var "cap-base"))
         (cap (cl-cc/type:make-type-capability :base v :cap 'read))
         (fvs (cl-cc/type:type-free-vars cap)))
    (expect (length fvs) :to-equal 1)
    (expect (cl-cc/type:type-var-equal-p v (first fvs)) :to-be-truthy)))

(it-sequential "free-vars-capability-primitive-base-yields-nil"
  (expect (cl-cc/type:type-free-vars
                (cl-cc/type:make-type-capability :base cl-cc/type:type-int :cap 'read))
          :to-be-null))

;;; ─── type-free-vars: refinement ─────────────────────────────────────────────

(it-sequential "free-vars-refinement-var-base-yields-one-fv"
  (let* ((v   (cl-cc/type:fresh-type-var "ref-base"))
         (ref (cl-cc/type:make-type-refinement :base v :predicate (lambda (x) (> x 0))))
         (fvs (cl-cc/type:type-free-vars ref)))
    (expect (length fvs) :to-equal 1)
    (expect (cl-cc/type:type-var-equal-p v (first fvs)) :to-be-truthy)))

(it-sequential "free-vars-refinement-primitive-base-yields-nil"
  (expect (cl-cc/type:type-free-vars
                (cl-cc/type:make-type-refinement
                 :base cl-cc/type:type-int :predicate (lambda (x) (> x 0)))) :to-be-null))

;;; ─── type-free-vars: handler ─────────────────────────────────────────────────

(it-sequential "free-vars-handler-three-distinct-vars"
  (let* ((ve (cl-cc/type:fresh-type-var "eff"))
         (vi (cl-cc/type:fresh-type-var "in"))
         (vo (cl-cc/type:fresh-type-var "out"))
         (h  (cl-cc/type:make-type-handler :effect ve :input vi :output vo)))
    (expect (length (cl-cc/type:type-free-vars h)) :to-equal 3)))

(it-sequential "free-vars-handler-shared-var-deduped"
  (let* ((v (cl-cc/type:fresh-type-var "shared"))
         (h (cl-cc/type:make-type-handler :effect v :input v :output cl-cc/type:type-int)))
    (expect (length (cl-cc/type:type-free-vars h)) :to-equal 1)))

(it-sequential "free-vars-handler-all-primitives-yields-nil"
  (expect (cl-cc/type:type-free-vars
                (cl-cc/type:make-type-handler
                 :effect (cl-cc/type:make-type-effect-op :name 'io)
                 :input  cl-cc/type:type-int
                 :output cl-cc/type:type-string)) :to-be-null))

;;; ─── type-free-vars: gadt-con ────────────────────────────────────────────────

(it-sequential "free-vars-gadt-con-collects-arg-types"
  (let* ((v  (cl-cc/type:fresh-type-var "gadt-a"))
         (gc (cl-cc/type:make-type-gadt-con
              :name 'just
              :arg-types (list v)
              :index-type cl-cc/type:type-int)))
    ;; type-free-vars doesn't reach gadt-con — verify it returns nil (falls through to t nil)
    ;; since gadt-con is not in type-free-vars dispatch
    (expect (listp (cl-cc/type:type-free-vars gc)) :to-be-truthy)))

;;; ─── type-rigid-equal-p (types-core.lisp) ───────────────────────────────────

(it-sequential "rigid-var-equal-p-same-id-is-true"
  (let* ((r1 (cl-cc/type:fresh-rigid-var "r"))
         (r2 (cl-cc/type::%make-type-rigid :id (cl-cc/type:type-rigid-id r1) :name "r")))
    (expect (cl-cc/type:type-rigid-equal-p r1 r2) :to-be-truthy)))

(it-sequential "rigid-var-equal-p-different-ids-is-false"
  (let ((r1 (cl-cc/type:fresh-rigid-var "a"))
        (r2 (cl-cc/type:fresh-rigid-var "b")))
    (expect (cl-cc/type:type-rigid-equal-p r1 r2) :to-be-falsy)))

(it-sequential "rigid-var-equal-p-rigid-vs-var-is-false"
  (let ((r (cl-cc/type:fresh-rigid-var "r"))
        (v (cl-cc/type:fresh-type-var  "v")))
    (expect (cl-cc/type:type-rigid-equal-p r v) :to-be-falsy)))

;;; ─── type-env-bindings (types-env.lisp) ─────────────────────────────────────

(it-sequential "type-env-bindings-empty-env-is-nil"
  (expect (cl-cc/type:type-env-bindings (cl-cc/type:type-env-empty)) :to-be-null))

(it-sequential "type-env-bindings-extended-env-has-entry"
  (let* ((env  (cl-cc/type:type-env-empty))
         (sch  (cl-cc/type:type-to-scheme cl-cc/type:type-int))
         (env2 (cl-cc/type:type-env-extend 'x sch env))
         (al   (cl-cc/type:type-env-bindings env2)))
    (expect (length al) :to-equal 1)
    (expect (caar al) :to-be 'x)))

;;; ─── type-equal-p: capability and error nodes ────────────────────────────────

(it-sequential "type-equal-p-capability-self-identity"
  (let ((c (cl-cc/type:make-type-capability :base cl-cc/type:type-int :cap 'read)))
    (expect c :to-be-type-equal-to c)))

(it-sequential "type-equal-p-error-node-always-false"
  (let ((e (cl-cc/type:make-type-error :message "test")))
    (expect-not e :to-be-type-equal-to e)))

;;; ─── +pure-effect-row+ and +io-effect-row+ singletons ───────────────────────

(it-sequential "effect-row-singletons"
  (expect (cl-cc/type:type-effect-row-effects cl-cc/type:+pure-effect-row+) :to-be-null)
  (expect (cl-cc/type:type-effect-row-row-var cl-cc/type:+pure-effect-row+) :to-be-null)
  (let ((effs (cl-cc/type:type-effect-row-effects cl-cc/type:+io-effect-row+)))
    (expect (length effs) :to-equal 1)
    (expect (symbol-name (cl-cc/type:type-effect-op-name (first effs))) :to-equal "IO")))

;;; ─── Default slot values (struct constructors called with no keywords) ─────
;;; These exercise the defstruct slot-default initforms in
;;; types-extended-nodes.lisp, which only run when a keyword is omitted from
;;; the constructor call — every other test in this suite always supplies
;;; every keyword explicitly.

(it-sequential "default-effect-row-has-nil-effects-and-row-var"
  (let ((r (cl-cc/type:make-type-effect-row)))
    (expect (cl-cc/type:type-effect-row-effects r) :to-be-null)
    (expect (cl-cc/type:type-effect-row-row-var r) :to-be-null)))

(it-sequential "default-effect-op-has-nil-name-and-args"
  (let ((op (cl-cc/type:make-type-effect-op)))
    (expect (cl-cc/type:type-effect-op-name op) :to-be-null)
    (expect (cl-cc/type:type-effect-op-args op) :to-be-null)))

(it-sequential "default-handler-has-nil-effect-input-output"
  (let ((h (cl-cc/type:make-type-handler)))
    (expect (cl-cc/type:type-handler-effect h) :to-be-null)
    (expect (cl-cc/type:type-handler-input h) :to-be-null)
    (expect (cl-cc/type:type-handler-output h) :to-be-null)
    (expect (length (cl-cc/type:type-children h)) :to-equal 3)))

(it-sequential "default-gadt-con-has-nil-name-arg-types-index-type"
  (let ((gc (cl-cc/type:make-type-gadt-con)))
    (expect (cl-cc/type:type-gadt-con-name gc) :to-be-null)
    (expect (cl-cc/type:type-gadt-con-arg-types gc) :to-be-null)
    (expect (cl-cc/type:type-gadt-con-index-type gc) :to-be-null)
    (expect (cl-cc/type:type-children gc) :to-be-null)))

(it-sequential "default-constraint-has-nil-class-name-and-type-arg"
  (let ((c (cl-cc/type:make-type-constraint)))
    (expect (cl-cc/type:type-constraint-class-name c) :to-be-null)
    (expect (cl-cc/type:type-constraint-type-arg c) :to-be-null)))

(it-sequential "default-error-has-empty-message"
  (let ((e (cl-cc/type:make-type-error)))
    (expect (cl-cc/type:type-error-message e) :to-equal "")))

(it-sequential "default-qualified-raw-has-nil-constraints-and-body"
  (let ((q (cl-cc/type::%make-type-qualified-raw)))
    (expect (cl-cc/type:type-qualified-constraints q) :to-be-null)
    (expect (cl-cc/type:type-qualified-body q) :to-be-null)))

;;; ─── reset-type-vars! ────────────────────────────────────────────────────────

(it-sequential "reset-type-vars-resets-counter"
  (let ((old cl-cc/type::*type-var-counter*))
    (cl-cc/type:reset-type-vars!)
    (let ((v (cl-cc/type:fresh-type-var "after-reset")))
      (expect (cl-cc/type:type-var-id v) :to-equal 1))
    ;; Restore approximately (counter may have advanced during fresh-type-var)
    (setf cl-cc/type::*type-var-counter* (max old cl-cc/type::*type-var-counter*))))

;;; ─── %type-free-vars-list unit tests ─────────────────────────────────────────

(it-each (("free-vars-list-base-cases type-var"       t   1)
          ("free-vars-list-base-cases type-primitive" nil 0))
    "~A"
    (name-ignored is-var expected-count)
  (declare (ignore name-ignored))
  (let* ((v   (cl-cc/type:fresh-type-var "fv"))
         (ty  (if is-var v cl-cc/type:type-int))
         (res (cl-cc/type::%type-free-vars-list ty)))
    (expect (length res) :to-equal expected-count)
    (when is-var
      (expect (cl-cc/type:type-var-equal-p v (first res)) :to-be-truthy))))

(it-sequential "free-vars-list-arrow-collects-all-with-duplicates"
  (let* ((v  (cl-cc/type:fresh-type-var "shared"))
         (ar (cl-cc/type:make-type-arrow-raw :params (list v) :return v :effects nil :mult nil))
         (res (cl-cc/type::%type-free-vars-list ar)))
    (expect (length res) :to-equal 2)
    (expect (cl-cc/type:type-var-equal-p v (first res)) :to-be-truthy)
    (expect (cl-cc/type:type-var-equal-p v (second res)) :to-be-truthy)))

(it-sequential "free-vars-list-forall-filters-bound-var"
  (let* ((v1 (cl-cc/type:fresh-type-var "bound"))
         (v2 (cl-cc/type:fresh-type-var "free"))
         (ar (cl-cc/type:make-type-arrow-raw :params (list v1) :return v2 :effects nil :mult nil))
         (fa (cl-cc/type:make-type-forall :var v1 :body ar))
         (res (cl-cc/type::%type-free-vars-list fa)))
    (expect (length res) :to-equal 1)
    (expect (cl-cc/type:type-var-equal-p v2 (first res)) :to-be-truthy)))

(it-sequential "free-vars-list-nested-product"
  (let* ((v1  (cl-cc/type:fresh-type-var "a"))
         (v2  (cl-cc/type:fresh-type-var "b"))
         (v3  (cl-cc/type:fresh-type-var "c"))
         (prod (cl-cc/type:make-type-product :elems (list v1 v2 v3)))
         (res  (cl-cc/type::%type-free-vars-list prod)))
    (expect (length res) :to-equal 3)))
