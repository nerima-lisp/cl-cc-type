(defpackage :cl-cc/type/stm/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/stm
                #:stm #:make-tvar #:stm-bind #:stm-read #:stm-write
                #:atomically #:stm-return #:stm-action-result-type
                #:make-stm-type)
  (:import-from #:cl-cc/type/type-model
                #:type-int #:type-advanced-p
                #:type-advanced-name #:type-advanced-args)
  (:import-from #:cl-cc/type-test-support #:internal-function))