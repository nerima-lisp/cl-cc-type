;;;; t/type-system-test.lisp - Type System Tests
;;;;
;;;; Comprehensive tests for the HM type system including:
;;;; - Type representation (primitives, variables, functions)
;;;; - Unification (with occurs check)
;;;;
;;;; Direct-dispatch AST inference tests (Algorithm W, generalization and
;;;; instantiation, let-polymorphism) live in t/type-system-inference-test.lisp.

(in-package :cl-cc-type/test)

;;; Type Representation Tests

(progn
  (it-sequential "type-repr-primitive-is-type-primitive int"
    (let ((tp type-int))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive string"
    (let ((tp type-string))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive bool"
    (let ((tp type-bool))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive symbol"
    (let ((tp type-symbol))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive null"
    (let ((tp type-null))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive any"
    (let ((tp type-any))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive))))

(progn
  (it-sequential "type-repr-primitive-name int"
    (let ((tp type-int) (expected-name 'fixnum))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name string"
    (let ((tp type-string) (expected-name 'string))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name bool"
    (let ((tp type-bool) (expected-name 'boolean))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name symbol"
    (let ((tp type-symbol) (expected-name 'symbol))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name null"
    (let ((tp type-null) (expected-name 'null))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name any"
    (let ((tp type-any) (expected-name 't))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name))))

(it-sequential "type-repr-variable-and-function-creation"
  ;; Variables: distinct IDs, correct names
  (let ((v1 (fresh-type-var :name 'a))
        (v2 (fresh-type-var :name 'b)))
    (expect v1 :to-be-instance-of 'type-var)
    (expect v2 :to-be-instance-of 'type-var)
    (expect (= (type-var-id v1) (type-var-id v2)) :to-be-falsy)
    (expect (type-var-name v1) :to-be 'a)
    (expect (type-var-name v2) :to-be 'b))
  ;; Function type: accessors
  (let ((fn-type (make-type-arrow-raw
                  :params (list type-int type-int)
                  :return type-int)))
    (expect fn-type :to-be-instance-of 'type-arrow)
    (expect (length (type-arrow-params fn-type)) :to-equal 2)
    (expect (type-arrow-return fn-type) :to-be type-int)))

(progn
  (it-sequential "type-repr-equality-and-strings primitive-same"
    (let ((verify (lambda ()
                    (expect type-int :to-be-type-equal-to type-int))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings primitive-distinct"
    (let ((verify (lambda ()
                    (expect-not type-int :to-be-type-equal-to type-string))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings variable-self"
    (let ((verify (lambda ()
                    (let ((v (fresh-type-var)))
                      (expect v :to-be-type-equal-to v)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings function-equal"
    (let ((verify (lambda ()
                    (let ((fn1 (make-type-arrow-raw :params (list type-int) :return type-int))
                          (fn2 (make-type-arrow-raw :params (list type-int) :return type-int)))
                      (expect fn2 :to-be-type-equal-to fn1)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings function-different"
    (let ((verify (lambda ()
                    (let ((fn1 (make-type-arrow-raw :params (list type-int)    :return type-int))
                          (fn3 (make-type-arrow-raw :params (list type-string) :return type-int)))
                      (expect-not fn1 :to-be-type-equal-to fn3)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings arrow-to-string"
    (let ((verify (lambda ()
                    (let ((fn (make-type-arrow-raw :params (list type-int) :return type-int)))
                      (expect (type-to-string fn) :to-equal "FIXNUM -> FIXNUM")))))
      (declare (ignorable verify))
      (funcall verify))))

(progn
  (it-sequential "type-repr-primitive-type-to-string int"
    (let ((expected "FIXNUM") (type type-int))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected)))
  (it-sequential "type-repr-primitive-type-to-string string"
    (let ((expected "STRING") (type type-string))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected)))
  (it-sequential "type-repr-primitive-type-to-string bool"
    (let ((expected "BOOLEAN") (type type-bool))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected)))
  (it-sequential "type-repr-primitive-type-to-string unknown"
    (let ((expected "?") (type cl-cc/type:+type-unknown+))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected))))


(it-sequential "type-repr-unknown-type"
  (expect-not cl-cc/type:+type-unknown+ :to-be-type-equal-to cl-cc/type:+type-unknown+)
  (expect (type-error-p cl-cc/type:+type-unknown+) :to-be-truthy))

;;; Unification Tests

(progn
  (it-sequential "unify-primitive same"
    (let ((should-unify t) (a type-int) (b type-int))
      (declare (ignorable should-unify a b))
      (if should-unify
          (expect b :to-unify-with a)
          (expect-not b :to-unify-with a))))
  (it-sequential "unify-primitive different"
    (let ((should-unify nil) (a type-int) (b type-string))
      (declare (ignorable should-unify a b))
      (if should-unify
          (expect b :to-unify-with a)
          (expect-not b :to-unify-with a)))))

(progn
  (it-sequential "unify-advanced-cases variable-binds"
    (let ((verify (lambda ()
                    (let ((v (fresh-type-var)))
                      (multiple-value-bind (result ok) (type-unify v type-int)
                        (expect ok :to-be-truthy)
                        (multiple-value-bind (binding found) (subst-lookup v result)
                          (expect found :to-be-truthy)
                          (expect type-int :to-be-type-equal-to binding))))
                    (expect (fresh-type-var) :to-unify-with (fresh-type-var))
                    (let ((v (fresh-type-var)))
                      (expect v :to-unify-with v)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "unify-advanced-cases structural-binding"
    (let ((verify (lambda ()
                    (let* ((v   (fresh-type-var))
                           (fn1 (make-type-arrow-raw :params (list v) :return type-int))
                           (fn2 (make-type-arrow-raw :params (list type-string) :return type-int)))
                      (multiple-value-bind (result ok) (type-unify fn1 fn2)
                        (expect ok :to-be-truthy)
                        (multiple-value-bind (binding found) (subst-lookup v result)
                          (expect found :to-be-truthy)
                          (expect type-string :to-be-type-equal-to binding)))))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "unify-advanced-cases failure-cases"
    (let ((verify (lambda ()
                    (expect-not
                     (make-type-arrow-raw :params (list type-int type-int) :return type-int)
                     :to-unify-with
                     (make-type-arrow-raw :params (list type-int) :return type-int))
                    (let* ((v  (fresh-type-var))
                           (fn (make-type-arrow-raw :params (list v) :return type-int)))
                      (expect-not fn :to-unify-with v)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "unify-advanced-cases subst-chains"
    (let ((verify (lambda ()
                    (let* ((v1       (fresh-type-var))
                           (v2       (fresh-type-var))
                           (s1       (subst-extend v1 type-int (make-substitution)))
                           (s2       (subst-extend v2 v1 (make-substitution)))
                           (composed (subst-compose s1 s2)))
                      (expect (zonk v2 composed) :to-be-type-equal-to type-int))
                    (let* ((v1 (fresh-type-var))
                           (v2 (fresh-type-var)))
                      (multiple-value-bind (subst1 ok1) (type-unify v1 v2)
                        (expect ok1 :to-be-truthy)
                        (multiple-value-bind (subst2 ok2) (type-unify v2 type-int subst1)
                          (expect ok2 :to-be-truthy)
                          (expect (zonk v1 subst2) :to-be-type-equal-to type-int)))))))
      (declare (ignorable verify))
      (funcall verify))))

(progn
  (it-sequential "unify-lists success"
    (let ((expected t) (a (list type-int type-string)) (b (list type-int type-string)))
      (declare (ignorable expected a b))
      (let ((ok (nth-value 1 (type-unify-lists a b nil))))
        (expect (not (null ok)) :to-equal expected))))
  (it-sequential "unify-lists type-mismatch"
    (let ((expected nil) (a (list type-int type-string)) (b (list type-string type-int)))
      (declare (ignorable expected a b))
      (let ((ok (nth-value 1 (type-unify-lists a b nil))))
        (expect (not (null ok)) :to-equal expected))))
  (it-sequential "unify-lists length-mismatch"
    (let ((expected nil) (a (list type-int)) (b (list type-int type-string)))
      (declare (ignorable expected a b))
      (let ((ok (nth-value 1 (type-unify-lists a b nil))))
        (expect (not (null ok)) :to-equal expected)))))

(progn
  (it-sequential "unify-type-error-fails unknown-int"
    (let ((a cl-cc/type:+type-unknown+) (b type-int))
      (declare (ignorable a b))
      (expect-not b :to-unify-with a)))
  (it-sequential "unify-type-error-fails string-unknown"
    (let ((a type-string) (b cl-cc/type:+type-unknown+))
      (declare (ignorable a b))
      (expect-not b :to-unify-with a)))
  (it-sequential "unify-type-error-fails unknown-unknown"
    (let ((a cl-cc/type:+type-unknown+) (b cl-cc/type:+type-unknown+))
      (declare (ignorable a b))
      (expect-not b :to-unify-with a))))
