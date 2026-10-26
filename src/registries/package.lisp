(defpackage :cl-cc/type/registries
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model #:type-any #:type-to-scheme)
  (:export #:*smt-solver-registry*
           #:*type-alias-registry*
           #:*type-checker-plugin-registry*
           #:*type-interface-registry*
           #:*type-synthesis-strategy-registry*
           #:define-registry
           #:lookup-smt-solver
           #:lookup-type-alias
           #:lookup-type-checker-plugin
           #:lookup-type-interface
           #:lookup-type-interface-export
           #:lookup-type-synthesis-strategy
           #:register-smt-solver
           #:register-type-alias
           #:register-type-checker-plugin
           #:register-type-interface-data
           #:register-type-synthesis-strategy
           #:run-type-checker-plugin
           #:run-type-synthesis
           #:solve-smt-constraint
           #:type-interface-module
           #:type-interface-module-exported-types
           #:type-interface-module-exports
           #:type-interface-module-fingerprint
           #:type-interface-module-name
           #:type-interface-module-p)
)
