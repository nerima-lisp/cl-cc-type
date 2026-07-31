;;;; t/types-extended-advanced-validators-test.lisp — Advanced Validators Tests
;;;;
;;;; Tests for src/types-extended-advanced-validators.lisp:
;;;; the %type-advanced-validate-* family, exercised via parse-type-specifier
;;;; error paths for units-of-measure, QTT (FR-3401), and dependent (FR-1901)
;;;; advanced type forms.

(in-package :cl-cc-type/test)

(it-sequential "advanced-validators-now-use-concrete-semantic-modules"
  (signals error
      (cl-cc/type:parse-type-specifier '(units-of-measure float :unit furlong)))
  (signals error
      (cl-cc/type:parse-type-specifier '(advanced fr-3401 2 fixnum :evidence (proof impossible))))
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1901 recursive-length :evidence (mystery proof))))
  (let ((route (cl-cc/type:parse-type-specifier '(api-type (get "/users/{id}" integer user)))))
    (expect (cl-cc/type:type-advanced-valid-p route) :to-be-truthy)))

(it-sequential "advanced-validate-information-flow-fr-1503-checks-target-rank-and-declassification-evidence"
  ;; Unknown :flow target label is rejected outright.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1503 (secret 1) :flow :nonexistent-label)))
  ;; Downgrading a secret source to a public target requires evidence.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1503 (secret 1) :flow :public)))
  ;; The same downgrade succeeds once declassification evidence is supplied.
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1503 (secret 1) :flow :public :evidence (declassify audited)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy))
  ;; Upgrading a public source to a secret target never needs evidence.
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1503 (public 1) :flow :secret))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy))
  ;; With no :flow target at all, the source/target comparison is skipped entirely.
  (let ((node (cl-cc/type:parse-type-specifier '(advanced fr-1503 (secret 1)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-type-safe-ffi-fr-2103-checks-raw-descriptor-form-shape"
  (signals error
      (cl-cc/type:parse-type-specifier '(type-safe-ffi (c-ptr))))
  (let ((node (cl-cc/type:parse-type-specifier '(type-safe-ffi (c-ptr c-int) c-string))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-route-fr-3305-rejects-a-malformed-route-payload"
  (signals error
      (cl-cc/type:parse-type-specifier '(api-type (get "/users/{id}")))))

(it-sequential "advanced-validate-proof-like-accepts-well-formed-termination-and-curry-howard-evidence"
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1901 recursive-length :evidence (termination :structural 5 3 1)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy))
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-2001 my-lemma :evidence (proof my-lemma-witness)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-proof-like-rejects-malformed-curry-howard-proof-evidence"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2001 my-lemma :evidence (nonsense x)))))

(it-sequential "advanced-validate-brand-fr-3205-requires-a-symbolic-or-string-brand-name"
  (signals error
      (cl-cc/type:parse-type-specifier '(brand-type 42 integer)))
  (let ((node (cl-cc/type:parse-type-specifier '(brand-type user-id integer))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy))
  (let ((node (cl-cc/type:parse-type-specifier '(brand-type "UserId" integer))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-synthesis-fr-3003-requires-evidence-for-proof-search-strategy"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-3003 (-> integer integer) :search :proof-search :fuel 8)))
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-3003 (-> integer integer)
                 :search :proof-search :fuel 8 :evidence (proof search-goal)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-mapped-types-fr-3301-checks-base-and-filter-shapes"
  ;; A base that is neither a type node, a structured form, nor a symbolic
  ;; designator is rejected even though :transform is well-formed.
  (signals error
      (cl-cc/type:parse-type-specifier '(mapped-type 42 :transform optional)))
  ;; A :filter that is not symbolic, a cons form, or a type node is rejected.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(mapped-type (list fixnum) :transform optional :filter 42)))
  ;; A symbolic :filter predicate is accepted.
  (let ((node (cl-cc/type:parse-type-specifier
               '(mapped-type (list fixnum) :transform optional :filter evenp))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-type-theory-equality-fr-3405-checks-intensional-payload-equality"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(type-theory-equality integer string :mode :intensional)))
  (let ((node (cl-cc/type:parse-type-specifier
               '(type-theory-equality integer integer :mode :intensional))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-qtt-fr-3401-accepts-a-valid-multiplicity-designator"
  (let ((node (cl-cc/type:parse-type-specifier '(qtt :one integer))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-staging-fr-1703-checks-quote-transition-and-run-stage-mismatch"
  ;; A :quote transition never requires stage-safety evidence and never hits
  ;; the :run-only stage check.
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1703 (quote integer) :stage 0 :transition :quote))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy))
  ;; A :run transition with evidence still fails when the declared stage is
  ;; neither 1 nor :code.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1703 (code integer) :stage 0 :transition :run
         :evidence (proof staged-eval)))))

(it-sequential "advanced-validate-staging-fr-1703-accepts-a-bare-type-node-payload"
  ;; %TYPE-ADVANCED-VALIDATE-STAGING's payload check, (OR (TYPEP payload
  ;; 'TYPE-NODE) (%TYPE-ADVANCED-STAGED-FORM-P payload)), only ever saw
  ;; its second disjunct via the (quote/code ...)-wrapped payloads above,
  ;; since those stay raw lists even after parsing. A bare primitive name
  ;; as the payload -- recognized and auto-parsed into a genuine type-node
  ;; by the advanced-value parser -- reaches the first disjunct directly.
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1703 integer :stage 1 :transition :quote))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-staging-fr-1703-rejects-a-payload-that-is-neither-shape"
  ;; Both disjuncts of the payload OR had only ever been observed true,
  ;; across the two tests above -- the VALIDATE-ADVANCED error branch
  ;; itself had never fired. A plain number is neither a TYPE-NODE nor a
  ;; CODE/QUOTE/SPLICE/RUN-headed form.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1703 42 :stage 1 :transition :quote))))

(it-sequential "advanced-validate-alias-analysis-fr-2902-rejects-non-pointer-operands"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2902 not-a-pointer (pointer integer) :disjoint nil :alias-class heap)))
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2902 (pointer integer) not-a-pointer :disjoint nil :alias-class heap))))

(it-sequential "advanced-validate-smt-integration-fr-2406-accepts-a-counterexample-in-place-of-evidence"
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-2406 (< v n) :solver :z3 :theory :lia
                 :counterexample (v -1)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-smt-integration-fr-2406-rejects-neither-evidence-nor-counterexample"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2406 (< v n) :solver :z3 :theory :lia))))

(it-sequential "advanced-validate-incremental-checking-fr-1606-rejects-identical-graph-and-cache"
  ;; The property-predicates for FR-1606 only check :dependency-graph and
  ;; :cache independently (each a symbolic designator); the custom
  ;; validator's own "must be distinct" cross-property check is the only
  ;; place this shape of error is caught.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1606 cache-entry :dependency-graph same-thing :cache same-thing))))

(it-sequential "advanced-validate-test-generation-fr-2101-rejects-samples-over-coverage-target"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2101 some-generator :generator (arbitrary integer)
         :coverage-target 10 :samples 20)))
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-2101 some-generator :generator (arbitrary integer)
                 :coverage-target 10 :samples 5))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-abstract-interpretation-fr-2804-rejects-identical-widening-and-narrowing"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2804 some-domain :domain interval :widening same-op :narrowing same-op)))
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-2804 some-domain :domain interval :widening widen-op
                 :narrowing narrow-op))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy))
  ;; FR-2804's contract only requires :DOMAIN and :WIDENING; :NARROWING is
  ;; optional, so TYPE-ADVANCED-PROPERTY-PRESENT-P's own (... :NARROWING)
  ;; check had only ever been observed true across the two cases above.
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-2804 some-domain :domain interval :widening widen-op))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-plugins-fr-3002-rejects-a-non-symbolic-plugin-name"
  ;; Unlike FR-3302's :INFER property (already caught earlier, before the
  ;; custom validator runs, by its own registered property-predicate),
  ;; FR-3002's plugin name is a positional ARG, which the contract-level
  ;; property-predicate machinery never inspects at all.
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-3002 42 :hook my-hook :phase :solve))))

(it-sequential "advanced-validate-encodings-fr-3403-rejects-a-surface-head-mismatched-with-the-encoding-property"
  (signals error
      (cl-cc/type:parse-type-specifier '(scott-encoding some-payload :encoding :church)))
  (signals error
      (cl-cc/type:parse-type-specifier '(parigot-encoding some-payload :encoding :scott)))
  (let ((node (cl-cc/type:parse-type-specifier '(scott-encoding some-payload :encoding :scott))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-encodings-fr-3403-skips-the-head-check-for-the-generic-advanced-form"
  ;; The COND's CHURCH/SCOTT clauses are both reached-and-false by the
  ;; mismatch cases above (each stops earlier at its own head), so only
  ;; the PARIGOT-ENCODING clause's own false outcome -- reached, but not
  ;; matched -- had never been observed. The generic (ADVANCED FR-3403
  ;; ...) surface form (as opposed to a named CHURCH-/SCOTT-/PARIGOT-
  ;; ENCODING head) defaults TYPE-ADVANCED-NAME to 'ADVANCED, matching
  ;; none of the three clauses and falling through to the (T NIL) arm,
  ;; so no encoding/head mismatch is possible to check.
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-3403 some-payload :encoding :church))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-type-theory-equality-fr-3405-requires-evidence-for-extensional-and-observational-modes"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(type-theory-equality integer integer :mode :extensional)))
  (signals error
      (cl-cc/type:parse-type-specifier
       '(type-theory-equality integer integer :mode :observational)))
  (let ((node (cl-cc/type:parse-type-specifier
               '(type-theory-equality integer integer :mode :extensional
                 :evidence (bisimulation proof)))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)))

