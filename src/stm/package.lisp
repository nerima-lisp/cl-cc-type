(defpackage :cl-cc/type/stm
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:any #:type-any #:type-unit
                #:type-primitive-p #:type-primitive-name
                #:type-advanced-p #:type-advanced-name
                #:type-constructor-p #:type-constructor-name)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:stm
           #:tvar #:tvar-p #:tvar-type #:tvar-value
           #:stm-action #:stm-action-p #:stm-action-result-type
           #:stm-action-thunk #:stm-action-effects
           #:*stm-transaction-active*
           #:make-tvar #:stm-return #:stm-read #:stm-write
           #:stm-bind #:atomically #:make-stm-type))
