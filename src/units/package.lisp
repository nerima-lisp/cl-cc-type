(defpackage :cl-cc/type/units
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
   #:define-simple-condition #:type-system-error
   #:type-advanced-property)
  (:import-from #:cl-cc/type/advanced-metadata
   #:register-type-advanced-validator
   #:%type-advanced-invalid)
  (:export
   #:unit-mismatch-error #:unit-definition #:unit-definition-p #:unit-definition-name
   #:unit-definition-dimension #:unit-definition-scale #:*unit-registry*
   #:define-unit #:find-unit #:unit-designator-p #:unit-dimension= #:unit-compatible-p
   #:measure #:measure-p #:measure-value #:measure-unit #:make-measure
   #:convert-unit #:convert-measure #:measure+ #:measure- #:measure*
   #:measure/))
