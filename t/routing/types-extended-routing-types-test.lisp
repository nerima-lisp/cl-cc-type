;;;; t/types-extended-routing-types-test.lisp — Typed Routing Tests
;;;;
;;;; Tests for src/types-extended-routing-types.lisp (FR-3305):
;;;; the ROUTE/API-SPEC structs, route-template-parameters, route-valid-p,
;;;; build-route-path, match-route-path, api-spec-valid-p, route-form-valid-p,
;;;; and the route-validation-error condition.
;;;;
;;;; t/routing-test.lisp exercises src/routing.lisp's make-api-type,
;;;; api-route-lookup, and route-response-type-for (a different, related
;;;; file); this file focuses on the lower-level route/api-spec primitives
;;;; defined directly in types-extended-routing-types.lisp, including the
;;;; negative/invalid-input branches that the happy-path routing tests do
;;;; not reach.

(in-package :cl-cc/type/routing/test)

(it-sequential "route-template-parameters-extracts-zero-one-and-multiple-placeholders"
  (expect (route-template-parameters "/health") :to-equal nil)
  (expect (route-template-parameters "/") :to-equal nil)
  (expect (route-template-parameters "/users/{id}/posts/{post-id}")
          :to-equal '(:ID :POST-ID)))

(it-sequential "route-valid-p-rejects-non-route-values"
  (expect (route-valid-p "not-a-route") :to-be-falsy)
  (expect (route-valid-p 42) :to-be-falsy))

(it-sequential "route-valid-p-rejects-structurally-invalid-routes"
  ;; %make-route bypasses make-route's validity check, so it can build
  ;; routes that route-valid-p itself must then reject.
  (expect (route-valid-p
           (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :bogus :path "/x" :parameters nil))
          :to-be-falsy)
  (expect (route-valid-p
           (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :get :path "" :parameters nil))
          :to-be-falsy)
  (expect (route-valid-p
           (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :get :path "no-leading-slash" :parameters nil))
          :to-be-falsy)
  (expect (route-valid-p
           (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :get :path "/users/{id}" :parameters nil))
          :to-be-falsy)
  (expect (route-valid-p
           (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :get :path "/users"
                                     :parameters '((:id . integer))))
          :to-be-falsy)
  (expect (route-valid-p
           (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :get :path "/users/{id}"
                                     :parameters '((:user-id . integer))))
          :to-be-falsy))

(it-sequential "normalize-route-parameters-treats-a-longer-entry-as-a-name-plus-rest-value"
  ;; %NORMALIZE-ROUTE-PARAMETERS' first COND clause matches an exactly-
  ;; 2-element (name value) list; every pre-existing test's entries were
  ;; either that shape or a (name . value) dotted pair, so the clause's
  ;; own (NULL (CDDR entry)) conjunct had only ever been observed true.
  ;; A 3+-element entry is still (CONSP entry), so it falls to the second
  ;; clause instead, pairing the name with the whole rest as its value.
  (expect (funcall (internal-function "cl-cc/type/routing" "%NORMALIZE-ROUTE-PARAMETERS") '((id integer :extra)))
          :to-equal (list (cons :ID '(integer :extra)))))

(it-sequential "parse-route-parameter-integer-catches-a-non-string-raw-value"
  ;; %PARSE-ROUTE-PARAMETER's INTEGER branch wraps PARSE-INTEGER in a
  ;; HANDLER-CASE; every call reachable through MATCH-ROUTE-PATH always
  ;; passes a genuine string segment, so PARSE-INTEGER never signals
  ;; there. A non-string RAW-VALUE (legal input to this internal function
  ;; even if no current caller produces one) makes PARSE-INTEGER itself
  ;; signal a type-error, reaching the handler directly.
  (expect (funcall (internal-function "cl-cc/type/routing" "%PARSE-ROUTE-PARAMETER") 42 'integer) :to-be-null))

(it-sequential "match-route-path-returns-nil-for-an-invalid-route"
  (let ((invalid-route (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :bogus :path "/x" :parameters nil)))
    (multiple-value-bind (matched params) (match-route-path invalid-route "/x")
      (expect matched :to-be-falsy)
      (expect params :to-be-null))))

(it-sequential "match-route-path-rejects-mismatched-segment-counts-and-literals"
  (let ((route (make-route :get "/users/{id}" :parameters '((id integer)))))
    (multiple-value-bind (matched params) (match-route-path route "/users/42/extra")
      (expect matched :to-be-falsy)
      (expect params :to-be-null))
    (multiple-value-bind (matched params) (match-route-path route "/accounts/42")
      (expect matched :to-be-falsy)
      (expect params :to-be-null))))

(it-sequential "match-route-path-rejects-a-template-parameter-that-fails-to-parse"
  (let ((route (make-route :get "/users/{id}" :parameters '((id integer)))))
    (multiple-value-bind (matched params) (match-route-path route "/users/abc")
      (expect matched :to-be-falsy)
      (expect params :to-be-null))))

(it-sequential "match-route-path-parses-string-and-keyword-typed-parameters"
  (let ((string-route (make-route :get "/greet/{name}" :parameters '((name string))))
        (keyword-route (make-route :get "/mode/{mode}" :parameters '((mode keyword)))))
    (multiple-value-bind (matched params) (match-route-path string-route "/greet/anyone")
      (expect matched :to-be-truthy)
      (expect params :to-equal '((:NAME . "anyone"))))
    (multiple-value-bind (matched params) (match-route-path keyword-route "/mode/fast")
      (expect matched :to-be-truthy)
      (expect params :to-equal '((:MODE . :FAST))))))

(it-sequential "match-route-path-falls-back-to-typep-for-other-type-designators"
  (let ((array-route (make-route :get "/item/{item}" :parameters '((item array))))
        (null-route (make-route :get "/nope/{x}" :parameters '((x null)))))
    (multiple-value-bind (matched params) (match-route-path array-route "/item/thing")
      (expect matched :to-be-truthy)
      (expect params :to-equal '((:ITEM . "thing"))))
    (multiple-value-bind (matched params) (match-route-path null-route "/nope/thing")
      (expect matched :to-be-falsy)
      (expect params :to-be-null))))

(it-sequential "build-route-path-signals-for-an-invalid-route"
  (let ((invalid-route (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :bogus :path "/x" :parameters nil)))
    (signals route-validation-error
        (build-route-path invalid-route nil))))

(it-sequential "build-route-path-signals-when-a-required-parameter-is-missing"
  (let ((route (make-route :get "/users/{id}" :parameters '((id integer)))))
    (signals route-validation-error
        (build-route-path route nil))))

(it-sequential "build-route-path-renders-literal-only-paths-without-parameters"
  (let ((route (make-route :get "/health" :parameters nil)))
    (expect (build-route-path route nil) :to-equal "/health")))

(it-sequential "api-spec-valid-p-rejects-non-api-spec-values"
  (expect (api-spec-valid-p "nope") :to-be-falsy)
  (expect (api-spec-valid-p 42) :to-be-falsy))

(it-sequential "api-spec-valid-p-rejects-a-spec-containing-an-invalid-route"
  (let* ((valid-route (make-route :get "/ok" :parameters nil))
         (invalid-route (funcall (internal-function "cl-cc/type/routing" "%MAKE-ROUTE") :method :bogus :path "/x" :parameters nil))
         (api-spec (funcall (internal-function "cl-cc/type/routing" "MAKE-API-SPEC") :routes (list valid-route invalid-route))))
    (expect (api-spec-valid-p api-spec) :to-be-falsy)))

(it-sequential "api-spec-valid-p-rejects-duplicate-method-and-path-routes"
  (let* ((route-a (make-route :get "/dup" :parameters nil :response-type 'a))
         (route-b (make-route :get "/dup" :parameters nil :response-type 'b))
         (api-spec (funcall (internal-function "cl-cc/type/routing" "MAKE-API-SPEC") :routes (list route-a route-b))))
    (expect (api-spec-valid-p api-spec) :to-be-falsy)))

(it-sequential "api-spec-valid-p-accepts-distinct-methods-on-the-same-path"
  (let* ((get-route (make-route :get "/x" :parameters nil))
         (post-route (make-route :post "/x" :parameters nil))
         (api-spec (funcall (internal-function "cl-cc/type/routing" "MAKE-API-SPEC") :routes (list get-route post-route))))
    (expect (api-spec-valid-p api-spec) :to-be-truthy)))

(it-sequential "route-form-valid-p-validates-the-structural-shape-of-raw-route-forms"
  (expect (route-form-valid-p nil) :to-be-falsy)
  (expect (route-form-valid-p '(:get)) :to-be-falsy)
  (expect (route-form-valid-p '(:bogus "/x" 1)) :to-be-falsy)
  (expect (route-form-valid-p '(:get 42 1)) :to-be-falsy)
  (expect (route-form-valid-p '(:get "/users/{id}/posts/{pid}" 1)) :to-be-falsy)
  (expect (route-form-valid-p '(:get "/health" :payload)) :to-be-truthy)
  (expect (route-form-valid-p '(:post "/users/{id}" 42 :extra)) :to-be-truthy))

(it-sequential "route-validation-error-signals-for-malformed-parameter-entries"
  (signals route-validation-error
      (make-route :get "/x" :parameters '(:oops))))

(it-sequential "route-validation-error-signals-when-make-route-builds-an-invalid-route"
  (signals route-validation-error
      (make-route :get "no-leading-slash" :parameters nil)))

(it-sequential "route-validation-error-report-formats-the-signaled-detail"
  (handler-case
      (make-route :get "no-leading-slash" :parameters nil)
    (route-validation-error (condition)
      (expect (search "Invalid route" (format nil "~A" condition)) :to-be-truthy))))
