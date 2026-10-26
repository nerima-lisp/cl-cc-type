(in-package #:cl-cc/type/ffi/test)

(it-sequential "advanced-validate-type-safe-ffi-fr-2103-checks-raw-descriptor-form-shape"
  (signals error
      (make-type-advanced :feature-id "FR-2103" :name 'type-safe-ffi :args (list '(c-ptr))))
  (let ((node (make-type-advanced :feature-id "FR-2103" :name 'type-safe-ffi :args (list '(c-ptr c-int) 'c-string))))
    (expect (type-advanced-valid-p node) :to-be-truthy)))

