;;;; t/types-extended-advanced-node-test.lisp — Advanced Type-Node Accessors Tests
;;;;
;;;; Tests for src/types-extended-advanced-node.lisp:
;;;; make-type-dynamic/make-type-type-rep node construction, the advanced
;;;; payload-tree helpers, property/security-label/route accessors, the
;;;; QTT/graded keyword-surface normalizer, and (types-extended-advanced-meta.lisp's
;;;; closely related) feature/head registry lookups.

(in-package :cl-cc/type/type-lowering/test)

(it-sequential "qtt-and-graded-keyword-surface-normalizes-to-positional-multiplicity-args"
  (let* ((node (parse-type-specifier '(graded :omega x))))
    (expect (type-advanced-valid-p node) :to-be-truthy)
    (expect (type-advanced-feature-id node) :to-equal "FR-3402")
    (expect (= (length (type-advanced-args node)) 2) :to-be-truthy))
  (signals error (parse-type-specifier '(graded :grade x))))

(defun %expect-parsed-feature-id (form expected-id)
  (let ((node (parse-type-specifier form)))
    (expect (type-advanced-feature-id node) :to-equal expected-id)
    node))

(it-sequential "parser-associates-feature-ids-with-incremental-staging-and-generator-heads"
  (%expect-parsed-feature-id
   '(advanced fr-1606 cache-entry :dependency-graph call-graph :cache module-cache :lsp t)
   "FR-1606")
  (%expect-parsed-feature-id
   '(advanced fr-1703 (code integer) :stage 1 :transition :run :evidence (proof staged-eval))
   "FR-1703")
  (%expect-parsed-feature-id '(advanced fr-1801 (lens a b s t) :lawful t)
                             "FR-1801")
  (%expect-parsed-feature-id
   '(advanced fr-2101 (list integer) :generator (arbitrary integer)
     :coverage-target 100 :samples 20)
   "FR-2101"))

(it-sequential "parser-associates-feature-ids-with-analysis-and-tooling-heads"
  (%expect-parsed-feature-id
   '(advanced fr-2405 user-module :exports (lookup save) :fingerprint "sha256:abc")
   "FR-2405")
  (%expect-parsed-feature-id
   '(advanced fr-2406 (< v n) :solver :z3 :theory :lia :evidence (proof smt-discharge))
   "FR-2406")
  (%expect-parsed-feature-id
   '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing narrow)
   "FR-2804")
  (%expect-parsed-feature-id
   '(advanced fr-2902 (pointer integer) (pointer float) :disjoint t :alias-class heap)
   "FR-2902")
  (%expect-parsed-feature-id
   '(advanced fr-3002 nat-normalise :hook solver :phase :solve)
   "FR-3002")
  (%expect-parsed-feature-id
   '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 8)
   "FR-3003"))

(it-sequential "parser-associates-feature-ids-with-structural-and-equality-heads"
  (%expect-parsed-feature-id '(mapped-type (list fixnum) :transform optional)
                             "FR-3301")
  (%expect-parsed-feature-id
   '(conditional-type (list fixnum) :extends list :infer item :then item :else null)
   "FR-3302")
  (%expect-parsed-feature-id '(church-encoding integer :encoding :church)
                             "FR-3403")
  (%expect-parsed-feature-id '(open-union (io state) fixnum)
                             "FR-3404")
  (%expect-parsed-feature-id
   '(type-theory-equality (-> integer integer) (-> integer integer)
     :mode :extensional :evidence (proof functional-extensionality))
   "FR-3405"))

(it-sequential "parser-preserves-encoding-surface-head-and-property-fields"
  (signals error
      (parse-type-specifier '(scott-encoding some-payload :encoding :church)))
  (signals error
      (parse-type-specifier '(parigot-encoding some-payload :encoding :scott)))
  (let ((node (parse-type-specifier '(scott-encoding some-payload :encoding :scott))))
    (expect (type-advanced-name node) :to-be 'scott-encoding)
    (expect (type-advanced-feature-id node) :to-equal "FR-3403")
    (expect (type-advanced-property node :encoding) :to-be :scott))
  (let ((node (parse-type-specifier '(parigot-encoding some-payload :encoding :parigot))))
    (expect (type-advanced-name node) :to-be 'parigot-encoding)
    (expect (type-advanced-feature-id node) :to-equal "FR-3403")
    (expect (type-advanced-property node :encoding) :to-be :parigot))
  (let ((node (parse-type-specifier '(advanced fr-3403 some-payload :encoding :church))))
    (expect (type-advanced-name node) :to-be 'advanced)
    (expect (type-advanced-feature-id node) :to-equal "FR-3403")
    (expect (type-advanced-property node :encoding) :to-be :church)))

(it-sequential "parse-units-measure-surface-rejects-an-unknown-unit"
  (signals error
      (parse-type-specifier '(units-of-measure float :unit furlong))))

(it-sequential "parse-proof-like-surface-preserves-totality-and-curry-howard-cases"
  (signals error
      (parse-type-specifier
       '(advanced fr-1901 recursive-length :evidence (mystery proof))))
  (%expect-parsed-feature-id
   '(advanced fr-1901 recursive-length :evidence (termination :structural 5 3 1))
   "FR-1901")
  (%expect-parsed-feature-id
   '(advanced fr-2001 my-lemma :evidence (proof my-lemma-witness))
   "FR-2001")
  (signals error
      (parse-type-specifier
       '(advanced fr-2001 my-lemma :evidence (nonsense x)))))

(it-sequential "parse-information-flow-surface-preserves-validator-cases"
  (signals error
      (parse-type-specifier
       '(advanced fr-1503 (secret 1) :flow :nonexistent-label)))
  (signals error
      (parse-type-specifier '(advanced fr-1503 (secret 1) :flow :public)))
  (%expect-parsed-feature-id
   '(advanced fr-1503 (secret 1) :flow :public :evidence (declassify audited))
   "FR-1503")
  (%expect-parsed-feature-id
   '(advanced fr-1503 (public 1) :flow :secret)
   "FR-1503")
  (%expect-parsed-feature-id
   '(advanced fr-1503 (secret 1))
   "FR-1503"))

(it-sequential "parse-type-safe-ffi-surface-preserves-descriptor-cases"
  (signals error
      (parse-type-specifier '(type-safe-ffi (c-ptr))))
  (%expect-parsed-feature-id
   '(type-safe-ffi (c-ptr c-int) c-string)
   "FR-2103"))
