;;;; t/unification-advanced-nodes-test.lisp — Advanced Feature Node Unification Tests
;;;;
;;;; Tests for src/unification.lisp:
;;;; type-unify over type-advanced nodes (%type-advanced-unify,
;;;; %unify-payload-pairs, %type-advanced-payload-unify, %unify-property-alist).
;;;; Split out of t/unification-test.lisp (one of two "%<source>-<observation>-test.lisp"
;;;; angle files for src/unification.lisp; see t/unification-test.lisp and
;;;; t/unification-effect-rows-test.lisp for the other angles).

(in-package :cl-cc-type/test)

;;; ─── Advanced Feature Node Unification ──────────────────────────────────
;;; %type-advanced-unify / %unify-payload-pairs / %type-advanced-payload-unify
;;; / %unify-property-alist were entirely unexercised: no test previously
;;; unified two type-advanced nodes at all.

(it-sequential "unify-advanced-same-feature-succeeds"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :name 'widget
                                          :args (list cl-cc/type:type-int)
                                          :properties '((:mode . strict))))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :name 'widget
                                          :args (list cl-cc/type:type-int)
                                          :properties '((:mode . strict)))))
    (multiple-value-bind (s ok) (type-unify a b)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-advanced-different-feature-id-fails"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :name 'widget))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9002" :name 'widget)))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-mismatched-typed-args-fail"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list cl-cc/type:type-int)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-type-node-vs-plain-arg-fails"
  ;; one side's arg is a type-node, the other's is a plain symbol at the same
  ;; cons position: exercises the "shapes don't match" payload branch.
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list cl-cc/type:type-int)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list 'not-a-type))))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-nonequal-plain-args-fail"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :args (list 1)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :args (list 2))))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-equal-evidence-atoms-succeed"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :evidence "proof"))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :evidence "proof")))
    (multiple-value-bind (s ok) (type-unify a b)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(progn
  (it-sequential "unify-advanced-property-alist-cases length-mismatch"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict) (:extra . t)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-advanced-property-alist-cases key-missing"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:other . strict)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-advanced-property-alist-cases value-mismatch"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . loose)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-advanced-property-alist-cases typed-value-unifies"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-int))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-int)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:substitution-p s) :to-be-truthy))))
  (it-sequential "unify-advanced-property-alist-cases typed-value-fails"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-int))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-string)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))
