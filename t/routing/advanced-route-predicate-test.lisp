;;;; t/types-extended-advanced-node-test.lisp — Advanced Type-Node Accessors Tests
;;;;
;;;; Tests for src/types-extended-advanced-node.lisp:
;;;; make-type-dynamic/make-type-type-rep node construction, the advanced
;;;; payload-tree helpers, property/security-label/route accessors, the
;;;; QTT/graded keyword-surface normalizer, and (types-extended-advanced-meta.lisp's
;;;; closely related) feature/head registry lookups.

(in-package :cl-cc/type/routing/test)

(it-sequential "type-advanced-route-p-recognizes-valid-routes-and-rejects-other-values"
  (expect (type-advanced-route-p
           (make-route :get "/x" :parameters nil :response-type 'y))
          :to-be-truthy)
  (expect (type-advanced-route-p 42) :to-be-falsy))

