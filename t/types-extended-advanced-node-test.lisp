;;;; t/types-extended-advanced-node-test.lisp — Advanced Type-Node Accessors Tests
;;;;
;;;; Tests for src/types-extended-advanced-node.lisp:
;;;; make-type-dynamic/make-type-type-rep node construction, the advanced
;;;; payload-tree helpers, property/security-label/route accessors, the
;;;; QTT/graded keyword-surface normalizer, and (types-extended-advanced-meta.lisp's
;;;; closely related) feature/head registry lookups.

(in-package :cl-cc-type/test)

(it-sequential "make-type-dynamic-and-make-type-type-rep-build-valid-fr-2501-and-fr-2502-nodes"
  (let ((dyn (cl-cc/type:make-type-dynamic cl-cc/type:type-int)))
    (expect (cl-cc/type:type-advanced-p dyn) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id dyn) :to-equal "FR-2501")
    (expect (cl-cc/type:type-advanced-valid-p dyn) :to-be-truthy))
  (let ((rep (cl-cc/type:make-type-type-rep cl-cc/type:type-string)))
    (expect (cl-cc/type:type-advanced-p rep) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id rep) :to-equal "FR-2502")
    (expect (cl-cc/type:type-advanced-valid-p rep) :to-be-truthy)))

(it-sequential "advanced-payload-tree-helpers-walk-nested-type-node-structures"
  (let* ((tree (list cl-cc/type:type-int (cons 'wrapped cl-cc/type:type-string) "plain"))
         (children (cl-cc/type::type-advanced-payload-children tree)))
    (expect (= (length children) 2) :to-be-truthy)
    (expect (every (lambda (c) (typep c 'cl-cc/type:type-node)) children) :to-be-truthy))
  (let* ((tree (list cl-cc/type:type-int (cons 'wrapped cl-cc/type:type-string)))
         (mapped (cl-cc/type::type-advanced-payload-map
                  (lambda (ty) (declare (ignore ty)) cl-cc/type:type-bool)
                  tree)))
    (expect (first mapped) :to-be-type-equal-to cl-cc/type:type-bool)
    (expect (cdr (second mapped)) :to-be-type-equal-to cl-cc/type:type-bool))
  (expect (cl-cc/type::type-advanced-payload-equal-p
           (list cl-cc/type:type-int "x") (list cl-cc/type:type-int "x"))
          :to-be-truthy)
  (expect (cl-cc/type::type-advanced-payload-equal-p cl-cc/type:type-int "not-a-type-node")
          :to-be-falsy)
  (expect (cl-cc/type::type-advanced-payload-equal-p
           (list cl-cc/type:type-int) (list cl-cc/type:type-string))
          :to-be-falsy)
  (expect (cl-cc/type::type-advanced-properties-equal-p
           '((:a . 1) (:b . 2)) '((:b . 2) (:a . 1)))
          :to-be-truthy)
  (expect (cl-cc/type::type-advanced-properties-equal-p '((:a . 1)) '((:a . 1) (:b . 2)))
          :to-be-falsy)
  ;; The above mismatched-length case short-circuits on the (= (length ...))
  ;; check before the LOOP's own ALWAYS clause ever runs; these two same-
  ;; length cases reach the loop and fail it for each of its two distinct
  ;; reasons: a key present in PROPS1 missing from PROPS2 (ENTRY2 is NIL),
  ;; and a key present in both whose payloads differ.
  (expect (cl-cc/type::type-advanced-properties-equal-p
           '((:a . 1) (:b . 2)) '((:a . 1) (:c . 2)))
          :to-be-falsy)
  (expect (cl-cc/type::type-advanced-properties-equal-p '((:a . 1)) '((:a . 2)))
          :to-be-falsy))

(it-sequential "advanced-feature-registry-listing-and-head-lookup-helpers"
  (let ((ids (cl-cc/type:list-type-advanced-feature-ids))
        (features (cl-cc/type:list-type-advanced-features)))
    (expect (> (length ids) 0) :to-be-truthy)
    (expect (equal ids (sort (copy-list ids) #'string<)) :to-be-truthy)
    (expect (= (length ids) (length features)) :to-be-truthy)
    (expect (member "FR-1803" ids :test #'string=) :to-be-truthy))
  (expect (cl-cc/type:type-advanced-feature-id-for-head 'qtt) :to-equal "FR-3401")
  (expect (cl-cc/type:type-advanced-feature-id-for-head "QTT") :to-equal "FR-3401")
  (expect (cl-cc/type:type-advanced-feature-id-for-head 'not-a-registered-head) :to-be-null)
  (expect (cl-cc/type:type-advanced-head-p 'qtt) :to-be-truthy)
  (expect (cl-cc/type:type-advanced-head-p 'advanced) :to-be-truthy)
  (expect (cl-cc/type:type-advanced-head-p 'not-a-registered-head) :to-be-falsy)
  (expect (cl-cc/type:type-advanced-head-p 42) :to-be-falsy)
  (signals error (cl-cc/type:canonicalize-type-advanced-feature-id 42)))

(it-sequential "advanced-node-property-accessors-security-label-and-route-predicate"
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1606 cache-entry
                 :dependency-graph call-graph :cache module-cache :lsp t))))
    (expect (cl-cc/type:type-advanced-property-present-p node :cache) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-property-present-p node :missing-property) :to-be-falsy)
    (expect (cl-cc/type:type-advanced-property node :missing-property :fallback) :to-be :fallback))
  (expect (cl-cc/type:type-advanced-security-label<= :public :secret) :to-be-truthy)
  (expect (cl-cc/type:type-advanced-security-label<= :secret :public) :to-be-falsy)
  (expect (cl-cc/type:type-advanced-route-p
           (cl-cc/type:make-route :get "/x" :parameters nil :response-type 'y))
          :to-be-truthy)
  (expect (cl-cc/type:type-advanced-route-p 42) :to-be-falsy))

(it-sequential "type-advanced-payload-security-label-covers-every-label-and-both-fallbacks"
  ;; %TYPE-ADVANCED-PAYLOAD-SECURITY-LABEL's callers (types-extended-
  ;; advanced-validators.lisp, subtyping.lisp) only ever exercise :public
  ;; and :trusted payloads in their own test suites; drive the rest of the
  ;; COND directly, including the null-head and unrecognized-head arms.
  (expect (cl-cc/type::%type-advanced-payload-security-label '(public x)) :to-be :public)
  (expect (cl-cc/type::%type-advanced-payload-security-label '(trusted x)) :to-be :trusted)
  (expect (cl-cc/type::%type-advanced-payload-security-label '(tainted x)) :to-be :tainted)
  (expect (cl-cc/type::%type-advanced-payload-security-label '(secret x)) :to-be :secret)
  (expect (cl-cc/type::%type-advanced-payload-security-label '(top-secret x)) :to-be :top-secret)
  (expect (cl-cc/type::%type-advanced-payload-security-label '(unlabeled x)) :to-be-null)
  (expect (cl-cc/type::%type-advanced-payload-security-label "not-a-cons-form") :to-be-null))

(it-sequential "type-advanced-head-name-is-nil-for-a-non-cons-value"
  (expect (cl-cc/type::%type-advanced-head-name '(public x)) :to-equal "PUBLIC")
  (expect (cl-cc/type::%type-advanced-head-name 42) :to-be-null))

(it-sequential "type-advanced-property-sort-key-falls-back-to-prin1-for-non-symbol-keys"
  ;; %TYPE-ADVANCED-NORMALIZE-PROPERTIES's existing exercise (via
  ;; parse-type-specifier's :keyword property alists above) only ever
  ;; sorts CONSP entries with symbolp keys; a non-symbol key and a bare,
  ;; non-CONSP entry both need PRIN1-TO-STRING instead.
  (expect (cl-cc/type::%type-advanced-property-sort-key (cons :zeta 1)) :to-equal "ZETA")
  (expect (cl-cc/type::%type-advanced-property-sort-key (cons 42 1)) :to-equal "42")
  (expect (cl-cc/type::%type-advanced-property-sort-key 42) :to-equal "42"))

(it-sequential "qtt-and-graded-keyword-surface-normalizes-to-positional-multiplicity-args"
  (let* ((node (cl-cc/type:parse-type-specifier '(graded :omega x))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id node) :to-equal "FR-3402")
    (expect (= (length (cl-cc/type:type-advanced-args node)) 2) :to-be-truthy))
  (signals error (cl-cc/type:parse-type-specifier '(graded :grade x))))

