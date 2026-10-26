(defpackage :cl-cc/type/concurrency
  (:use #:cl)
  (:export
   #:concurrency-traits #:concurrency-traits-p #:make-concurrency-traits
   #:concurrency-traits-type #:concurrency-traits-send #:concurrency-traits-sync
   #:concurrency-traits-note #:*concurrency-trait-registry*
   #:register-concurrency-traits #:lookup-concurrency-traits
   #:sendable-type-p #:shareable-type-p #:validate-send #:validate-sync
   #:validate-spawn-argument #:validate-shared-reference))
