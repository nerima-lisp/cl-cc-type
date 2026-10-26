;;;; t/types-extended-advanced-node-test.lisp — Advanced Type-Node Accessors Tests
;;;;
;;;; Tests for src/types-extended-advanced-node.lisp:
;;;; make-type-dynamic/make-type-type-rep node construction, the advanced
;;;; payload-tree helpers, property/security-label/route accessors, the
;;;; QTT/graded keyword-surface normalizer, and (types-extended-advanced-meta.lisp's
;;;; closely related) feature/head registry lookups.

(in-package :cl-cc/type/advanced-metadata/test)

(it-sequential "make-type-dynamic-and-make-type-type-rep-build-valid-fr-2501-and-fr-2502-nodes"
  (let ((dyn (make-type-dynamic type-int)))
    (expect (type-advanced-p dyn) :to-be-truthy)
    (expect (type-advanced-feature-id dyn) :to-equal "FR-2501")
    (expect (type-advanced-valid-p dyn) :to-be-truthy))
  (let ((rep (make-type-type-rep type-string)))
    (expect (type-advanced-p rep) :to-be-truthy)
    (expect (type-advanced-feature-id rep) :to-equal "FR-2502")
    (expect (type-advanced-valid-p rep) :to-be-truthy)))

(in-package :cl-cc/type/advanced-metadata/test)

(it-sequential "printer-type-advanced-registered-surface-head"
  (expect (cl-cc/type/syntax:type-to-string (make-type-dynamic type-string))
          :to-match-inline-snapshot "\"(DYNAMIC STRING)\""))

(it-sequential "printer-type-advanced-generic-head-full"
  (let ((adv (make-type-advanced
              :feature-id "FR-1802"
              :args (list 42 (list 1 2) type-int)
              :properties (list (cons :level 3) (cons :mode :fast))
              :evidence :confirmed)))
    (expect (cl-cc/type/syntax:type-to-string adv)
            :to-match-inline-snapshot
            "\"(ADVANCED FR-1802 42 (1 2) FIXNUM LEVEL 3 MODE :FAST :EVIDENCE :CONFIRMED)\"")))
