(defpackage #:cl-cc/type/capabilities/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/capabilities
                #:capability-allows-p #:capability-effects
                #:capability-implies-p #:capability-permissions
                #:make-capability #:restrict-capability))
