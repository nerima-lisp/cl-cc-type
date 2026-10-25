(in-package #:cl-cc/type/type-model/test)

(it-sequential "type-repr-unknown-type"
  (expect-not +type-unknown+ :to-be-type-equal-to +type-unknown+)
  (expect (type-error-p +type-unknown+) :to-be-truthy))

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
    (let ((expected "?") (type +type-unknown+))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected))))

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
