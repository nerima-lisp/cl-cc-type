;;;; t/types-extended-advanced-validators-test.lisp — Advanced Validators Tests
;;;;
;;;; Tests for src/types-extended-advanced-validators.lisp:
;;;; the %type-advanced-validate-* family, exercised via parse-type-specifier
;;;; error paths for units-of-measure, QTT (FR-3401), and dependent (FR-1901)
;;;; advanced type forms.

(in-package :cl-cc/type/routing/test)

(it-sequential "make-type-advanced-rejects-a-malformed-fr-3305-route-payload"
  (signals error
    (make-type-advanced
     :feature-id "FR-3305"
     :name 'api-type
     :args (list '(:get "/users/{id}")))))

(it-sequential "advanced-validate-route-fr-3305-rejects-a-malformed-route-payload"
  (signals error
      (parse-type-specifier '(api-type (get "/users/{id}")))))
