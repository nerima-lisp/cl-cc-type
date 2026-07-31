;;;; t/types-extended-concurrency-test.lisp — Concurrency Traits Tests
;;;;
;;;; Tests for src/types-extended-concurrency.lisp:
;;;; the Send/Sync concurrency-trait registry.

(in-package :cl-cc-type/test)

(it-sequential "concurrency-send-sync-registry-is-concrete"
  (cl-cc/type:register-concurrency-traits 'mutex-guard :send nil :sync nil :note :host-only)
  (cl-cc/type:register-concurrency-traits 'immutable-box :send t :sync t :note :value-object)
  (expect (cl-cc/type:sendable-type-p 'mutex-guard) :to-be-falsy)
  (expect (cl-cc/type:shareable-type-p 'mutex-guard) :to-be-falsy)
  (expect (cl-cc/type:validate-spawn-argument 'immutable-box) :to-be-truthy)
  (expect (cl-cc/type:validate-shared-reference 'immutable-box) :to-be-truthy)
  (expect (cl-cc/type:sendable-type-p 'integer) :to-be-truthy))

