;;;; t/stm-test.lisp — STM Types Tests
;;;;
;;;; Tests for src/stm.lisp (FR-2204):
;;;; STM action sequencing via stm-bind/stm-read/stm-write and effect rejection.

(in-package :cl-cc-type/test)

(it-sequential "concrete-stm-actions-sequence-and-reject-io-effects"
  (let* ((cell (cl-cc/type:make-tvar 'integer 1))
         (action (cl-cc/type:stm-bind
                  (cl-cc/type:stm-read cell)
                  (lambda (current)
                    (cl-cc/type:stm-bind
                     (cl-cc/type:stm-write cell (+ current 1))
                     (lambda (_)
                       (declare (ignore _))
                       (cl-cc/type:stm-read cell)))))))
    (expect (cl-cc/type:atomically action) :to-equal 2)
    (expect (cl-cc/type:atomically (cl-cc/type:stm-read cell)) :to-equal 2)
    (signals error
        (cl-cc/type:atomically
         (cl-cc/type::%make-stm-action :result-type cl-cc/type:type-int
                                       :thunk (lambda () 0)
                                       :effects '(:io))))))

(it-sequential "stm-return-lifts-a-plain-value-into-the-stm-monad"
  (expect (cl-cc/type:atomically (cl-cc/type:stm-return 42)) :to-equal 42)
  (expect (cl-cc/type:stm-action-result-type (cl-cc/type:stm-return 1 cl-cc/type:type-int))
          :to-be cl-cc/type:type-int))

(it-sequential "make-tvar-rejects-an-initial-value-that-does-not-match-its-type"
  (signals error
      (cl-cc/type:make-tvar 'integer "not-an-integer")))

(it-sequential "stm-read-and-stm-write-reject-a-non-tvar-argument"
  (signals error
      (cl-cc/type:stm-read "not-a-tvar"))
  (signals error
      (cl-cc/type:stm-write "not-a-tvar" 1)))

(it-sequential "stm-write-rejects-a-value-that-does-not-match-the-tvar-type"
  (let ((cell (cl-cc/type:make-tvar 'integer 1)))
    (signals error
        (cl-cc/type:stm-write cell "not-an-integer"))))

(it-sequential "stm-bind-rejects-a-non-stm-action-argument"
  (signals error
      (cl-cc/type:stm-bind "not-an-action" #'identity)))

(it-sequential "stm-bind-passes-through-a-plain-return-value-from-its-function"
  ;; The pre-existing test only ever chains FUNCTION back into another STM
  ;; action; the (if (stm-action-p next) ... next) branch that returns a
  ;; plain value straight through was never taken.
  (let ((action (cl-cc/type:stm-bind (cl-cc/type:stm-return 1)
                                     (lambda (x) (+ x 41)))))
    (expect (cl-cc/type:atomically action) :to-equal 42)))

(it-sequential "atomically-rejects-a-non-stm-action-argument"
  (signals error
      (cl-cc/type:atomically "not-an-action")))

(it-sequential "make-stm-type-builds-the-fr-2204-advanced-type-node"
  (let ((ty (cl-cc/type:make-stm-type cl-cc/type:type-int)))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::stm)
    (expect (cl-cc/type:type-advanced-args ty) :to-equal (list cl-cc/type:type-int))))

