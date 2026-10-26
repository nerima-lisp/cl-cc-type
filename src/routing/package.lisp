(defpackage :cl-cc/type/routing
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:define-simple-condition #:type-system-error
                #:define-keyword-normalizer #:error-with-detail
                #:require-with-detail #:type-advanced-args)
  (:import-from #:cl-cc/type/advanced-metadata
                #:make-type-advanced #:register-type-advanced-validator
                #:%type-advanced-invalid
                #:%type-advanced-require-min-args)
  (:export #:route-validation-error #:route-validation-error-detail
           #:route #:route-p #:route-method #:route-path
           #:route-parameters #:route-request-type #:route-response-type
           #:make-route #:route-valid-p #:route-template-parameters
           #:build-route-path #:match-route-path
           #:api-spec #:api-spec-p #:api-spec-routes #:api-spec-valid-p
           #:route-form-valid-p #:type-advanced-route-p
           #:make-api-type #:api-route-lookup #:route-response-type-for))