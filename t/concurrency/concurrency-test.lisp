;;;; t/types-extended-concurrency-test.lisp — Concurrency Traits Tests
;;;;
;;;; Tests for src/concurrency/types-extended-concurrency.lisp:
;;;; the Send/Sync concurrency-trait registry.

(in-package #:cl-cc/type/concurrency/test)

(it-sequential "concurrency-send-sync-registry-is-concrete"
  (register-concurrency-traits 'mutex-guard :send nil :sync nil :note :host-only)
  (register-concurrency-traits 'immutable-box :send t :sync t :note :value-object)
  (expect (sendable-type-p 'mutex-guard) :to-be-falsy)
  (expect (shareable-type-p 'mutex-guard) :to-be-falsy)
  (expect (validate-spawn-argument 'immutable-box) :to-be-truthy)
  (expect (validate-shared-reference 'immutable-box) :to-be-truthy)
  (expect (sendable-type-p 'integer) :to-be-truthy))

