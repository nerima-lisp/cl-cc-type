;;;; t/coroutines-test.lisp — Coroutine and Generator Types Tests
;;;;
;;;; Tests for src/coroutines/coroutines.lisp (FR-2205):
;;;; generator and coroutine runtime type enforcement.

(in-package :cl-cc/type/coroutines/test)

(it-sequential "concrete-coroutines-generators-and-coroutines-enforce-runtime-types"
  (let ((generator (make-generator 'integer '(1 2)
                                              :return-type 'string
                                              :final-value "done")))
    (multiple-value-bind (value done-p) (generator-next generator)
      (expect value :to-equal 1)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (generator-next generator)
      (expect value :to-equal 2)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (generator-next generator)
      (expect value :to-equal "done")
      (expect done-p :to-be-truthy)))
  (let ((coroutine (make-coroutine
                    'integer 'integer 'string
                    (lambda (value)
                      (if (plusp value)
                          (values (+ value 1) nil)
                          (values "done" t))))))
    (multiple-value-bind (value done-p) (coroutine-resume coroutine 3)
      (expect value :to-equal 4)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (coroutine-resume coroutine 0)
      (expect value :to-equal "done")
      (expect done-p :to-be-truthy)))
  (signals error
      (let ((coroutine (make-coroutine
                        'integer 'integer 'string
                        (lambda (_value)
                          (declare (ignore _value))
                          (values :wrong nil)))))
        (coroutine-resume coroutine 1))))

(it-sequential "make-generator-rejects-a-value-that-does-not-match-the-yield-type"
  (signals error
      (make-generator 'integer '(1 "two" 3))))

(it-sequential "generator-next-rejects-a-non-generator-argument"
  (signals error
      (generator-next "not-a-generator")))

(it-sequential "coroutine-resume-rejects-a-non-coroutine-argument"
  (signals error
      (coroutine-resume "not-a-coroutine" 1)))

(it-sequential "coroutine-resume-rejects-a-send-value-that-does-not-match-the-send-type"
  (let ((coroutine (make-coroutine
                    'integer 'integer 'string
                    (lambda (value) (values (+ value 1) nil)))))
    (signals error
        (coroutine-resume coroutine "not-an-integer"))))

(it-sequential "coroutine-resume-rejects-resuming-an-already-completed-coroutine"
  (let ((coroutine (make-coroutine
                    'integer 'integer 'string
                    (lambda (value)
                      (if (plusp value) (values (+ value 1) nil) (values "done" t))))))
    (coroutine-resume coroutine 0)
    (expect (typed-coroutine-done-p coroutine) :to-be-truthy)
    (signals error
        (coroutine-resume coroutine 1))))

(it-sequential "make-generator-type-and-make-coroutine-type-build-fr-2205-advanced-type-nodes"
  (let ((gen-type (make-generator-type type-int type-string)))
    (expect (type-advanced-p gen-type) :to-be-truthy)
    (expect (type-advanced-name gen-type) :to-be (quote generator))
    (expect (type-advanced-args gen-type)
            :to-equal (list type-int type-string)))
  (let ((co-type (make-coroutine-type
                  type-int type-bool type-string)))
    (expect (type-advanced-p co-type) :to-be-truthy)
    (expect (type-advanced-name co-type) :to-be (quote coroutine))
    (expect (type-advanced-args co-type)
            :to-equal (list type-int type-bool type-string))))

