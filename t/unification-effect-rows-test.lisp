;;;; t/unification-effect-rows-test.lisp — unify-effect-rows Remaining Branches Tests
;;;;
;;;; Tests for src/unification.lisp:
;;;; the unify-effect-rows branches not covered by t/unification-test.lisp's
;;;; basic Effect Row Unification section (both-row-vars-present, only-one-side-has-a-var,
;;;; extra-effects-on-one-side, and unique-effects-on-both-sides cases).

(in-package :cl-cc-type/test)

;;; ─── unify-effect-rows: remaining branches ──────────────────────────────
;;; Prior tests only exercised: both-sides-empty-no-row-vars, same-effects,
;;; open-absorbs-extra (row2 has extras, rv1 present), closed-rejects-extra
;;; (row2 has extras, rv1 absent). The branches below were unexercised.

(it-sequential "unify-effect-row-equal-sets-both-row-vars-unify-vars"
  (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
         (rv2 (cl-cc/type:fresh-type-var 'r2))
         (e (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv1))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv2)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-var-equal-p (zonk rv1 s) (zonk rv2 s)) :to-be-truthy))))

(it-sequential "unify-effect-row-equal-sets-only-row1-has-var"
  (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
         (e (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv1))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e) :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-effect-row-p (zonk rv1 s)) :to-be-truthy))))

(it-sequential "unify-effect-row-equal-sets-only-row2-has-var"
  (let* ((rv2 (cl-cc/type:fresh-type-var 'r2))
         (e (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e) :row-var nil))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv2)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-effect-row-p (zonk rv2 s)) :to-be-truthy))))

(progn
  (it-sequential "unify-effect-row-row1-extra-effects-cases row2-var-present-succeeds"
    (let* ((rv2 (cl-cc/type:fresh-type-var 'r2))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io e-exn) :row-var nil))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv2)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-effect-row-p (zonk rv2 s)) :to-be-truthy))))
  (it-sequential "unify-effect-row-row1-extra-effects-cases row2-var-absent-fails"
    (let* ((e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io e-exn) :row-var nil))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var nil)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

(progn
  (it-sequential "unify-effect-row-both-unique-effects-cases both-vars-present-succeeds"
    (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
           (rv2 (cl-cc/type:fresh-type-var 'r2))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv1))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-exn) :row-var rv2)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:substitution-p s) :to-be-truthy))))
  (it-sequential "unify-effect-row-both-unique-effects-cases missing-row-var-fails"
    (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv1))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-exn) :row-var nil)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-effect-row-both-unique-effects-cases both-vars-present-but-rv1-pre-bound-conflicts"
    ;; The "both-vars-present-succeeds" case above always unifies RV1
    ;; against a fresh (unbound) synthesized effect row, which trivially
    ;; succeeds; the (IF OK1 ... (FAIL)) branch for RV1's own unification
    ;; genuinely failing had never fired. Pre-binding RV1 to an unrelated
    ;; concrete type in the incoming substitution makes that inner
    ;; TYPE-UNIFY fail structurally (a type-var already bound to TYPE-INT
    ;; can't also unify with a TYPE-EFFECT-ROW), reaching it directly.
    (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
           (rv2 (cl-cc/type:fresh-type-var 'r2))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv1))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-exn) :row-var rv2))
           (subst (subst-extend rv1 cl-cc/type:type-int nil)))
      (multiple-value-bind (s ok) (type-unify r1 r2 subst)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

(it-sequential "unify-effect-row-tolerates-a-malformed-non-effect-op-entry"
  ;; %EFFECT-LABEL's (WHEN (TYPE-EFFECT-OP-P e) ...) guard has only ever
  ;; seen genuine TYPE-EFFECT-OP entries across every pre-existing effect
  ;; row in this suite; ROW1's list here deliberately contains a bare
  ;; symbol instead, mirroring the analogous
  ;; effect-node-name-signals-for-a-non-effect-op case for EFFECT.LISP's
  ;; own %EFFECT-NODE-NAME sibling in t/effect-test.lisp -- unification
  ;; degrades gracefully here rather than erroring, treating the
  ;; malformed entry as an effect with no name.
  (let* ((r1 (cl-cc/type:make-type-effect-row :effects (list 'not-an-effect-op) :row-var nil))
         (r2 (cl-cc/type:make-type-effect-row :effects nil :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))
