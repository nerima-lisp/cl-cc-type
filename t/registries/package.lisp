(defpackage #:cl-cc/type/registries/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/registries #:%default-smt-solver #:%default-type-plugin #:%default-type-synthesis #:%initialize-advanced-dispatch-registries #:lookup-smt-solver #:lookup-type-checker-plugin #:lookup-type-interface #:lookup-type-interface-export #:lookup-type-synthesis-strategy #:register-smt-solver #:register-type-checker-plugin #:register-type-synthesis-strategy #:run-type-checker-plugin #:run-type-synthesis #:solve-smt-constraint #:type-interface-module-p)
  (:import-from #:cl-cc/type-test-support #:internal-function #:internal-symbol)
  (:import-from #:cl-cc/type/type-model #:type-any #:type-int))
