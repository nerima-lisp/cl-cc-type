;;;; t/routing-test.lisp — Type-Safe Routing Tests
;;;;
;;;; Tests for src/routing.lisp (FR-3305):
;;;; route API-spec lookup, response-type resolution, path-parameter validation,
;;;; and path build/match roundtrips.

(in-package :cl-cc-type/test)

(it-sequential "concrete-routing-api-lookup-and-response-type-work"
  (let* ((users (cl-cc/type:make-route :get "/users/{id}"
                                       :parameters '((id integer))
                                       :response-type 'user))
         (health (cl-cc/type:make-route :get "/health"
                                        :parameters nil
                                        :response-type 'status))
         (api-spec (cl-cc/type::make-api-spec :routes (list users health)))
         (api-type (cl-cc/type:make-api-type :get "/users/{id}" '((id integer)) 'user)))
    (expect (cl-cc/type:type-advanced-p api-type) :to-be-truthy)
    (expect (cl-cc/type:api-spec-valid-p api-spec) :to-be-truthy)
    (multiple-value-bind (route params) (cl-cc/type:api-route-lookup api-spec :get "/users/42")
      (expect route :to-be-truthy)
      (expect params :to-equal '((:ID . 42))))
    (expect (cl-cc/type:route-response-type-for api-spec :get "/users/42") :to-be 'user)
    (expect (cl-cc/type:route-response-type-for api-spec :get "/missing") :to-be-null)
    ;; Every registered route is :GET, so a :POST lookup for an otherwise-
    ;; matching path must skip past each one via the DOLIST's (EQ
    ;; NORMALIZED-METHOD (ROUTE-METHOD ROUTE)) check returning false --
    ;; the pre-existing lookups above only ever exercised the true side.
    (multiple-value-bind (route params) (cl-cc/type:api-route-lookup api-spec :post "/users/42")
      (expect route :to-be-null)
      (expect params :to-be-null))))

(it-sequential "routing-validates-path-parameters-and-roundtrips"
  (let ((route (cl-cc/type:make-route :get "/users/{id}"
                                      :parameters '((id integer))
                                      :response-type 'user)))
    (expect (cl-cc/type:route-valid-p route) :to-be-truthy)
    (expect (cl-cc/type:build-route-path route '((:id . 42))) :to-equal "/users/42")
    (multiple-value-bind (matched params)
        (cl-cc/type:match-route-path route "/users/42")
      (expect matched :to-be-truthy)
      (expect params :to-equal '((:ID . 42))))
    (signals cl-cc/type:route-validation-error
        (cl-cc/type:build-route-path route '((:id . "forty-two"))))))

