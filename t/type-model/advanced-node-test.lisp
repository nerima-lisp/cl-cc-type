;;;; t/types-extended-advanced-node-test.lisp — Advanced Type-Node Accessors Tests
;;;;
;;;; Tests for src/types-extended-advanced-node.lisp:
;;;; make-type-dynamic/make-type-type-rep node construction, the advanced
;;;; payload-tree helpers, property/security-label/route accessors, the
;;;; QTT/graded keyword-surface normalizer, and (types-extended-advanced-meta.lisp's
;;;; closely related) feature/head registry lookups.

(in-package :cl-cc/type/type-model/test)

(it-sequential "advanced-payload-tree-helpers-walk-nested-type-node-structures"
  (let* ((tree (list type-int (cons 'wrapped type-string) "plain"))
         (children (type-advanced-payload-children tree)))
    (expect (= (length children) 2) :to-be-truthy)
    (expect (every (lambda (c) (typep c 'type-node)) children) :to-be-truthy))
  (let* ((tree (list type-int (cons 'wrapped type-string)))
         (mapped (type-advanced-payload-map
                  (lambda (ty) (declare (ignore ty)) type-bool)
                  tree)))
    (expect (first mapped) :to-be-type-equal-to type-bool)
    (expect (cdr (second mapped)) :to-be-type-equal-to type-bool))
  (expect (type-advanced-payload-equal-p
           (list type-int "x") (list type-int "x"))
          :to-be-truthy)
  (expect (type-advanced-payload-equal-p type-int "not-a-type-node")
          :to-be-falsy)
  (expect (type-advanced-payload-equal-p
           (list type-int) (list type-string))
          :to-be-falsy)
  (expect (type-advanced-properties-equal-p
           '((:a . 1) (:b . 2)) '((:b . 2) (:a . 1)))
          :to-be-truthy)
  (expect (type-advanced-properties-equal-p '((:a . 1)) '((:a . 1) (:b . 2)))
          :to-be-falsy)
  ;; The above mismatched-length case short-circuits on the (= (length ...))
  ;; check before the LOOP's own ALWAYS clause ever runs; these two same-
  ;; length cases reach the loop and fail it for each of its two distinct
  ;; reasons: a key present in PROPS1 missing from PROPS2 (ENTRY2 is NIL),
  ;; and a key present in both whose payloads differ.
  (expect (type-advanced-properties-equal-p
           '((:a . 1) (:b . 2)) '((:a . 1) (:c . 2)))
          :to-be-falsy)
  (expect (type-advanced-properties-equal-p '((:a . 1)) '((:a . 2)))
          :to-be-falsy))

(it-sequential "advanced-node-property-accessors-security-label-and-route-predicate"
  (let ((node (%make-type-advanced
               :feature-id "FR-1606"
               :name 'advanced
               :args '(cache-entry)
               :properties '((:dependency-graph . call-graph)
                             (:cache . module-cache)
                             (:lsp . t)))))
    (expect (type-advanced-property-present-p node :cache) :to-be-truthy)
    (expect (type-advanced-property-present-p node :missing-property) :to-be-falsy)
    (expect (type-advanced-property node :missing-property :fallback) :to-be :fallback)))

(it-sequential "type-advanced-property-sort-key-falls-back-to-prin1-for-non-symbol-keys"
  ;; %TYPE-ADVANCED-NORMALIZE-PROPERTIES's existing exercise (via
  ;; parse-type-specifier's :keyword property alists above) only ever
  ;; sorts CONSP entries with symbolp keys; a non-symbol key and a bare,
  ;; non-CONSP entry both need PRIN1-TO-STRING instead.
  (expect (%type-advanced-property-sort-key (cons :zeta 1)) :to-equal "ZETA")
  (expect (%type-advanced-property-sort-key (cons 42 1)) :to-equal "42")
  (expect (%type-advanced-property-sort-key 42) :to-equal "42"))

