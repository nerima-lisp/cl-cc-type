;;;; t/types-extended-regions-test.lisp — Region Lifetime Tests
;;;;
;;;; Tests for src/regions/types-extended-regions.lisp:
;;;; region-scoped references and with-region lifetime enforcement.

(in-package #:cl-cc/type/regions/test)

(it-sequential "region-tokens-enforce-lifetimes"
  (let (dangling)
    (with-region (region)
      (setf dangling (region-alloc region 42))
      (expect (region-ref-valid-p dangling) :to-be-truthy)
      (expect (region-deref dangling) :to-equal 42))
    (expect (region-ref-valid-p dangling) :to-be-falsy)
    (signals region-lifetime-error
        (region-deref dangling))))

(it-sequential "region-active-p-is-falsy-for-a-non-region-token-argument"
  (expect (region-active-p "not-a-region-token") :to-be-falsy))

(it-sequential "region-alloc-rejects-allocation-into-a-closed-region"
  (let ((region (make-region-token)))
    (close-region region)
    (signals error
        (region-alloc region 42))))

(it-sequential "region-ref-valid-p-is-falsy-when-the-ref-does-not-point-at-a-region-token"
  (expect (region-ref-valid-p
           (funcall (internal-function "cl-cc/type/regions" "MAKE-REGION-REF") :token "not-a-region-token" :generation 0 :value 1))
          :to-be-falsy))

