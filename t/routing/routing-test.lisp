;;;; t/routing-test.lisp — Type-Safe Routing Tests
;;;;
;;;; Tests for src/routing.lisp (FR-3305):
;;;; route API-spec lookup, response-type resolution, path-parameter validation,
;;;; and path build/match roundtrips.

(in-package :cl-cc/type/routing/test)

(it-sequential "concrete-routing-api-lookup-and-response-type-work"
  (let* ((users (make-route :get "/users/{id}"
                                       :parameters '((id integer))
                                       :response-type 'user))
         (health (make-route :get "/health"
                                        :parameters nil
                                        :response-type 'status))
         (api-spec (funcall (internal-function "cl-cc/type/routing" "MAKE-API-SPEC") :routes (list users health)))
         (api-type (make-api-type :get "/users/{id}" '((id integer)) 'user)))
    (expect (type-advanced-p api-type) :to-be-truthy)
    (expect (api-spec-valid-p api-spec) :to-be-truthy)
    (multiple-value-bind (route params) (api-route-lookup api-spec :get "/users/42")
      (expect route :to-be-truthy)
      (expect params :to-equal '((:ID . 42))))
    (expect (route-response-type-for api-spec :get "/users/42") :to-be 'user)
    (expect (route-response-type-for api-spec :get "/missing") :to-be-null)
    ;; Every registered route is :GET, so a :POST lookup for an otherwise-
    ;; matching path must skip past each one via the DOLIST's (EQ
    ;; NORMALIZED-METHOD (ROUTE-METHOD ROUTE)) check returning false --
    ;; the pre-existing lookups above only ever exercised the true side.
    (multiple-value-bind (route params) (api-route-lookup api-spec :post "/users/42")
      (expect route :to-be-null)
      (expect params :to-be-null))))

(it-sequential "routing-validates-path-parameters-and-roundtrips"
  (let ((route (make-route :get "/users/{id}"
                                      :parameters '((id integer))
                                      :response-type 'user)))
    (expect (route-valid-p route) :to-be-truthy)
    (expect (build-route-path route '((:id . 42))) :to-equal "/users/42")
    (multiple-value-bind (matched params)
        (match-route-path route "/users/42")
      (expect matched :to-be-truthy)
      (expect params :to-equal '((:ID . 42))))
    (signals route-validation-error
        (build-route-path route '((:id . "forty-two"))))))

