(defpackage #:cl-cc/type/security-labels/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/security-labels
                #:%type-advanced-head-name
                #:%type-advanced-payload-security-label
                #:declassify-labeled-value #:join-security-labels
                #:labeled-value-audit-trail #:labeled-value-flow-allowed-p
                #:labeled-value-tainted-p #:labeled-value-value
                #:make-labeled-value #:meet-security-labels
                #:normalize-security-label #:sanitize-labeled-value
                #:security-label-p #:security-label-rank #:security-label<=)
  (:import-from #:cl-cc/type/advanced-metadata
                #:make-type-advanced #:type-advanced-valid-p))
