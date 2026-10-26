(defpackage #:cl-cc/type/units/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/units
                #:convert-measure #:convert-unit #:define-unit #:find-unit
                #:make-measure #:measure* #:measure+ #:measure- #:measure/
                #:measure-unit #:measure-value #:unit-compatible-p
                #:unit-definition-dimension #:unit-definition-name
                #:unit-definition-p #:unit-definition-scale
                #:unit-designator-p #:unit-dimension= #:unit-mismatch-error)
  (:import-from #:cl-cc/type/advanced-metadata
                #:make-type-advanced)
  (:import-from #:cl-cc/type-test-support #:internal-function))
