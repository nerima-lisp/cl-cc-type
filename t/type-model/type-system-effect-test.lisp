;;;; t/type-system-effect-test.lisp - Type Effect, Free Variables, Substitution, and Rank-N Tests
;;;;
;;;; Covers: free variables, substitution, bidirectional checking, typeclass,
;;;; effect types, effect rows, and rank-N polymorphism (forall).

(in-package :cl-cc/type/type-model/test)

(before-each
  (reset-type-vars!))

;;; Free Variables Tests

(progn
  (it-sequential "free-vars-primitives int"
    (let ((ty type-int))
      (declare (ignorable ty))
      (expect (type-free-vars ty) :to-be-null)))
  (it-sequential "free-vars-primitives string"
    (let ((ty type-string))
      (declare (ignorable ty))
      (expect (type-free-vars ty) :to-be-null))))

(it-sequential "free-vars-single-var-returns-itself"
  (let* ((v  (fresh-type-var))
         (fv (type-free-vars v)))
    (expect (length fv) :to-equal 1)
    (expect (type-var-equal-p (first fv) v) :to-be-truthy)))

(it-sequential "free-vars-function-type-returns-param-and-return-vars"
  (let* ((v1 (fresh-type-var))
         (v2 (fresh-type-var))
         (fn (make-type-arrow-raw :params (list v1) :return v2))
         (fv (type-free-vars fn)))
    (expect (length fv) :to-equal 2)))

;;; Substitution Tests

;;; Normalize Type Variables Tests

;;; Phase 3: Bidirectional Type Checking Tests

;;; Phase 4: Typeclass Tests

;;; Phase 5: Effect Type Tests


;;; ─── Effect Inference Tests (infer-effects / infer-with-effects / check-body-effects) ─
;;;
;;; The tests above exercise the effect-row *data structure*. These tests drive
;;; infer-effects itself (inference-effects.lisp) via directly-built AST nodes.

;;; Phase 6: Rank-N Polymorphism Tests

(it-sequential "rankn-forall-creation-and-equality"
  (let* ((a  (fresh-type-var :name 'a))
         (fn (make-type-arrow (list a) a))
         (fa (make-type-forall :var a :body fn)))
    (expect (type-forall-p fa) :to-be-truthy)
    (expect (type-var-equal-p a (type-forall-var fa)) :to-be-truthy)
    (expect (typep (type-forall-body fa) 'type-arrow) :to-be-truthy)
    (let ((s (type-to-string fa)))
      (expect (stringp s) :to-be-truthy)
      (expect (search "A" (string-upcase s)) :to-be-truthy)))
  (let* ((a  (fresh-type-var :name 'a))
         (b  (fresh-type-var :name 'b))
         (fa (make-type-forall :var a :body (make-type-arrow (list a) a)))
         (fb (make-type-forall :var b :body (make-type-arrow (list b) b))))
    (expect-not fa :to-be-type-equal-to fb)))
