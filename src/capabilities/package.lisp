(defpackage :cl-cc/type/capabilities
  (:use #:cl)
  (:export
   #:capability #:capability-p #:capability-permissions #:make-capability
   #:capability-allows-p #:capability-implies-p #:restrict-capability
   #:capability-effects))
