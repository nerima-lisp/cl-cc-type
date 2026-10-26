;;;; t/stm-test.lisp — STM Types Tests
;;;;
;;;; Tests for src/stm/stm.lisp (FR-2204):
;;;; STM action sequencing via stm-bind/stm-read/stm-write and effect rejection.

(in-package :cl-cc/type/stm/test)

(it-sequential "concrete-stm-actions-sequence-and-reject-io-effects"
  (let* ((cell (make-tvar 'integer 1))
         (action (stm-bind
                  (stm-read cell)
                  (lambda (current)
                    (stm-bind
                     (stm-write cell (+ current 1))
                     (lambda (_)
                       (declare (ignore _))
                       (stm-read cell)))))))
    (expect (atomically action) :to-equal 2)
    (expect (atomically (stm-read cell)) :to-equal 2)
    (signals error
        (atomically
         (funcall (internal-function "cl-cc/type/stm" "%MAKE-STM-ACTION") :result-type type-int
                                       :thunk (lambda () 0)
                                       :effects '(:io))))))

(it-sequential "stm-return-lifts-a-plain-value-into-the-stm-monad"
  (expect (atomically (stm-return 42)) :to-equal 42)
  (expect (stm-action-result-type (stm-return 1 type-int))
          :to-be type-int))

(it-sequential "make-tvar-rejects-an-initial-value-that-does-not-match-its-type"
  (signals error
      (make-tvar 'integer "not-an-integer")))

(it-sequential "stm-read-and-stm-write-reject-a-non-tvar-argument"
  (signals error
      (stm-read "not-a-tvar"))
  (signals error
      (stm-write "not-a-tvar" 1)))

(it-sequential "stm-write-rejects-a-value-that-does-not-match-the-tvar-type"
  (let ((cell (make-tvar 'integer 1)))
    (signals error
        (stm-write cell "not-an-integer"))))

(it-sequential "stm-bind-rejects-a-non-stm-action-argument"
  (signals error
      (stm-bind "not-an-action" #'identity)))

(it-sequential "stm-bind-passes-through-a-plain-return-value-from-its-function"
  ;; The pre-existing test only ever chains FUNCTION back into another STM
  ;; action; the (if (stm-action-p next) ... next) branch that returns a
  ;; plain value straight through was never taken.
  (let ((action (stm-bind (stm-return 1)
                                     (lambda (x) (+ x 41)))))
    (expect (atomically action) :to-equal 42)))

(it-sequential "atomically-rejects-a-non-stm-action-argument"
  (signals error
      (atomically "not-an-action")))

(it-sequential "make-stm-type-builds-the-fr-2204-advanced-type-node"
  (let ((ty (make-stm-type type-int)))
    (expect (type-advanced-p ty) :to-be-truthy)
    (expect (type-advanced-name ty) :to-be (quote stm))
    (expect (type-advanced-args ty) :to-equal (list type-int))))

