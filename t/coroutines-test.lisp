;;;; t/coroutines-test.lisp — Coroutine and Generator Types Tests
;;;;
;;;; Tests for src/coroutines.lisp (FR-2205):
;;;; generator and coroutine runtime type enforcement.

(in-package :cl-cc-type/test)

(it-sequential "concrete-coroutines-generators-and-coroutines-enforce-runtime-types"
  (let ((generator (cl-cc/type:make-generator 'integer '(1 2)
                                              :return-type 'string
                                              :final-value "done")))
    (multiple-value-bind (value done-p) (cl-cc/type:generator-next generator)
      (expect value :to-equal 1)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (cl-cc/type:generator-next generator)
      (expect value :to-equal 2)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (cl-cc/type:generator-next generator)
      (expect value :to-equal "done")
      (expect done-p :to-be-truthy)))
  (let ((coroutine (cl-cc/type:make-coroutine
                    'integer 'integer 'string
                    (lambda (value)
                      (if (plusp value)
                          (values (+ value 1) nil)
                          (values "done" t))))))
    (multiple-value-bind (value done-p) (cl-cc/type:coroutine-resume coroutine 3)
      (expect value :to-equal 4)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (cl-cc/type:coroutine-resume coroutine 0)
      (expect value :to-equal "done")
      (expect done-p :to-be-truthy)))
  (signals error
      (let ((coroutine (cl-cc/type:make-coroutine
                        'integer 'integer 'string
                        (lambda (_value)
                          (declare (ignore _value))
                          (values :wrong nil)))))
        (cl-cc/type:coroutine-resume coroutine 1))))

(it-sequential "make-generator-rejects-a-value-that-does-not-match-the-yield-type"
  (signals error
      (cl-cc/type:make-generator 'integer '(1 "two" 3))))

(it-sequential "generator-next-rejects-a-non-generator-argument"
  (signals error
      (cl-cc/type:generator-next "not-a-generator")))

(it-sequential "coroutine-resume-rejects-a-non-coroutine-argument"
  (signals error
      (cl-cc/type:coroutine-resume "not-a-coroutine" 1)))

(it-sequential "coroutine-resume-rejects-a-send-value-that-does-not-match-the-send-type"
  (let ((coroutine (cl-cc/type:make-coroutine
                    'integer 'integer 'string
                    (lambda (value) (values (+ value 1) nil)))))
    (signals error
        (cl-cc/type:coroutine-resume coroutine "not-an-integer"))))

(it-sequential "coroutine-resume-rejects-resuming-an-already-completed-coroutine"
  (let ((coroutine (cl-cc/type:make-coroutine
                    'integer 'integer 'string
                    (lambda (value)
                      (if (plusp value) (values (+ value 1) nil) (values "done" t))))))
    (cl-cc/type:coroutine-resume coroutine 0)
    (expect (cl-cc/type:typed-coroutine-done-p coroutine) :to-be-truthy)
    (signals error
        (cl-cc/type:coroutine-resume coroutine 1))))

(it-sequential "make-generator-type-and-make-coroutine-type-build-fr-2205-advanced-type-nodes"
  (let ((gen-type (cl-cc/type:make-generator-type cl-cc/type:type-int cl-cc/type:type-string)))
    (expect (cl-cc/type:type-advanced-p gen-type) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-name gen-type) :to-be 'cl-cc/type::generator)
    (expect (cl-cc/type:type-advanced-args gen-type)
            :to-equal (list cl-cc/type:type-int cl-cc/type:type-string)))
  (let ((co-type (cl-cc/type:make-coroutine-type
                  cl-cc/type:type-int cl-cc/type:type-bool cl-cc/type:type-string)))
    (expect (cl-cc/type:type-advanced-p co-type) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-name co-type) :to-be 'cl-cc/type::coroutine)
    (expect (cl-cc/type:type-advanced-args co-type)
            :to-equal (list cl-cc/type:type-int cl-cc/type:type-bool cl-cc/type:type-string))))

