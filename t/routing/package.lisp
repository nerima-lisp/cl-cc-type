(defpackage #:cl-cc/type/routing/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/routing
                #:route-validation-error #:make-route #:route-valid-p
                #:route-template-parameters #:build-route-path
                #:match-route-path #:api-spec-valid-p
                #:route-form-valid-p #:type-advanced-route-p
                #:make-api-type #:api-route-lookup
                #:route-response-type-for)
  (:import-from #:cl-cc/type/type-model #:type-advanced-p)
  (:import-from #:cl-cc/type/advanced-metadata
                #:make-type-advanced #:type-advanced-valid-p)
  (:import-from #:cl-cc/type-test-support #:internal-function)
  (:import-from #:cl-cc/type/syntax #:parse-type-specifier))