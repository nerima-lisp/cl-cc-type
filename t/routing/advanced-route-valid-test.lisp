;;;; t/types-extended-advanced-validators-test.lisp — Advanced Validators Tests
;;;;
;;;; Tests for src/types-extended-advanced-validators.lisp:
;;;; the %type-advanced-validate-* family, exercised via parse-type-specifier
;;;; error paths for units-of-measure, QTT (FR-3401), and dependent (FR-1901)
;;;; advanced type forms.

(in-package :cl-cc/type/routing/test)

(it-sequential "type-advanced-valid-p-accepts-a-valid-fr-3305-api-type"
  (let ((route (make-api-type :get "/users/{id}" '((id integer)) 'user)))
    (expect (type-advanced-valid-p route) :to-be-truthy)))

(it-sequential "advanced-validate-route-fr-3305-accepts-a-valid-api-type-through-the-parser"
  (let ((route (parse-type-specifier
                '(api-type (get "/users/{id}" integer user)))))
    (expect (type-advanced-valid-p route) :to-be-truthy)))
