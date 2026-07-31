;;;; t/types-extended-regions-test.lisp — Region Lifetime Tests
;;;;
;;;; Tests for src/types-extended-regions.lisp:
;;;; region-scoped references and with-region lifetime enforcement.

(in-package :cl-cc-type/test)

(it-sequential "region-tokens-enforce-lifetimes"
  (let (dangling)
    (cl-cc/type:with-region (region)
      (setf dangling (cl-cc/type:region-alloc region 42))
      (expect (cl-cc/type:region-ref-valid-p dangling) :to-be-truthy)
      (expect (cl-cc/type:region-deref dangling) :to-equal 42))
    (expect (cl-cc/type:region-ref-valid-p dangling) :to-be-falsy)
    (signals cl-cc/type:region-lifetime-error
        (cl-cc/type:region-deref dangling))))

(it-sequential "region-active-p-is-falsy-for-a-non-region-token-argument"
  (expect (cl-cc/type:region-active-p "not-a-region-token") :to-be-falsy))

(it-sequential "region-alloc-rejects-allocation-into-a-closed-region"
  (let ((region (cl-cc/type:make-region-token)))
    (cl-cc/type:close-region region)
    (signals error
        (cl-cc/type:region-alloc region 42))))

(it-sequential "region-ref-valid-p-is-falsy-when-the-ref-does-not-point-at-a-region-token"
  (expect (cl-cc/type:region-ref-valid-p
           (cl-cc/type::make-region-ref :token "not-a-region-token" :generation 0 :value 1))
          :to-be-falsy))

