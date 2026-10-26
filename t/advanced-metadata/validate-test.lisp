;;;; t/types-extended-advanced-validate-test.lisp — Implementation-Evidence Completeness Tests
;;;;
;;;; Tests for src/types-extended-advanced-validate.lisp:
;;;; type-advanced-semantics-implemented-p and the module/API/test-anchor
;;;; evidence-availability helpers it composes.

(in-package :cl-cc/type/advanced-metadata/test)

(it-sequential "type-advanced-semantics-implemented-p-reflects-current-evidence-availability"
  ;; FR-1501's module/API/test-anchor evidence resolves against this standalone
  ;; checkout, so it reports implemented. An unknown feature id is never implemented.
  (expect (type-advanced-semantics-implemented-p "FR-1501") :to-be-truthy)
  (expect (type-advanced-semantics-implemented-p "FR-9999-NOT-A-FEATURE") :to-be-null)
  (expect
   (%type-advanced-implementation-api-available-p
    (find-symbol "MAKE-HLIST-TYPE" "CL-CC/TYPE/HLIST"))
   :to-be-truthy)
  (expect (%type-advanced-implementation-api-available-p 'totally-unbound-fn-xyz)
          :to-be-falsy)
  (expect (%type-advanced-implementation-api-available-p 42) :to-be-falsy)
  (expect (%type-advanced-implementation-module-present-p "src/hlist/types-hlist.lisp")
          :to-be-truthy)
  (expect (%type-advanced-implementation-module-present-p
           "packages/type/src/types-extended-nodes.lisp")
          :to-be-falsy)
  (expect (%type-advanced-implementation-module-present-p 42) :to-be-falsy)
  (expect (%type-advanced-implementation-test-anchor-available-p 42) :to-be-falsy))

(it-sequential "type-advanced-implementation-test-anchor-available-p-consults-known-test-names-registry"
  ;; This standalone checkout's :cl-cc-type/test package normally has no
  ;; *KNOWN-TEST-NAMES* registry (see the extensive docstring on
  ;; %type-advanced-implementation-test-anchor-available-p), so the test
  ;; above only exercises the permissive fallback ("registry absent -> T").
  ;; This test temporarily interns a *KNOWN-TEST-NAMES* hash table into the
  ;; live test package so the exact-match, case-prefix-search-match, and
  ;; no-match branches inside the registry-present half of the function all
  ;; run at least once, then removes the temporary binding again.
  (let* ((test-pkg (find-package :cl-cc-type/test))
         (registry-var (intern "*KNOWN-TEST-NAMES*" test-pkg))
         (exact-anchor-symbol (intern "ADVANCED-VALIDATE-EXACT-ANCHOR" test-pkg))
         (prefix-carrier-symbol
           (intern "SOME-SUITE/ADVANCED-VALIDATE-PREFIX-ANCHOR [case A]" test-pkg))
         (known-names (make-hash-table)))
    (setf (gethash exact-anchor-symbol known-names) "exact match case")
    (setf (gethash prefix-carrier-symbol known-names) "case-prefix match case")
    (unwind-protect
        (progn
          (setf (symbol-value registry-var) known-names)
          ;; An anchor whose name is an exact key of the registry hash hits
          ;; the direct GETHASH lookup.
          (expect (%type-advanced-implementation-test-anchor-available-p
                   :advanced-validate-exact-anchor)
                  :to-be-truthy)
          ;; No exact hash entry exists for this anchor, but a registered
          ;; test's ".../ANCHOR-NAME [case]" name contains
          ;; "/ANCHOR-NAME [" as a substring, so the fallback SEARCH loop
          ;; matches it.
          (expect (%type-advanced-implementation-test-anchor-available-p
                   :advanced-validate-prefix-anchor)
                  :to-be-truthy)
          ;; Neither an exact hash entry nor any case-prefix match exists.
          (expect (%type-advanced-implementation-test-anchor-available-p
                   :advanced-validate-unregistered-anchor)
                  :to-be-falsy))
      (makunbound registry-var)
      (unintern registry-var test-pkg)
      (unintern exact-anchor-symbol test-pkg)
      (unintern prefix-carrier-symbol test-pkg))))

(it-sequential "type-advanced-implementation-evidence-complete-p-checks-every-required-shape"
  ;; No evidence record at all.
  (expect (%type-advanced-implementation-evidence-complete-p nil) :to-be-falsy)
  ;; Modules must be a non-empty list.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST"
            :modules nil
            :api-symbols
            (list (find-symbol "MAKE-HLIST-TYPE" "CL-CC/TYPE/HLIST"))
            :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; API symbols must be a non-empty list.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/hlist/types-hlist.lisp")
            :api-symbols nil :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; Test anchors must be a non-empty list.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST"
            :modules '("src/hlist/types-hlist.lisp")
            :api-symbols
            (list (find-symbol "MAKE-HLIST-TYPE" "CL-CC/TYPE/HLIST"))
            :test-anchors nil))
          :to-be-falsy)
  ;; A module path that does not exist fails the module-presence EVERY check.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST"
            :modules '("src/does-not-exist-anywhere.lisp")
            :api-symbols
            (list (find-symbol "MAKE-HLIST-TYPE" "CL-CC/TYPE/HLIST"))
            :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; An unbound API symbol fails the api-available EVERY check.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/hlist/types-hlist.lisp")
            :api-symbols '(totally-unbound-fn-xyz) :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; A non-symbol test anchor fails the test-anchor-available EVERY check.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST"
            :modules '("src/hlist/types-hlist.lisp")
            :api-symbols
            (list (find-symbol "MAKE-HLIST-TYPE" "CL-CC/TYPE/HLIST"))
            :test-anchors '(42)))
          :to-be-falsy)
  ;; A fully well-formed record names a real module and a bound source API.
  (expect (%type-advanced-implementation-evidence-complete-p
           (%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST"
            :modules '("src/hlist/types-hlist.lisp")
            :api-symbols
            (list (find-symbol "MAKE-HLIST-TYPE" "CL-CC/TYPE/HLIST"))
            :test-anchors '(advanced-null-safety-option-parses-nullable-union)))
          :to-be-truthy))

(it-sequential "type-advanced-validate-contract-directly-exercises-arg-count-property-and-evidence-clauses"
  (let ((node (make-type-advanced :feature-id "FR-1501"
                                              :args (list type-int))))
    ;; When both exact-args and min-args are set, only exact-args is
    ;; enforced: the node's single arg satisfies exact-args 1 even though it
    ;; would violate a min-args of 5, and validation passes, returning the
    ;; node unchanged.
    (expect (%type-advanced-validate-contract
             node
             (make-type-advanced-contract
              :id "FR-1501" :semantic-domain :safety :exact-args 1 :min-args 5))
            :to-be node)
    ;; An exact-args mismatch signals.
    (signals error
        (%type-advanced-validate-contract
         node
         (make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :exact-args 2)))
    ;; min-args is enforced only when exact-args is absent.
    (signals error
        (%type-advanced-validate-contract
         node
         (make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :min-args 5)))
    ;; A required property absent from the node signals.
    (signals error
        (%type-advanced-validate-contract
         node
         (make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :required-properties '(:missing))))
    ;; A property-predicate keyed on a property the node does not have is
    ;; never consulted, so validation still passes.
    (expect (%type-advanced-validate-contract
             node
             (make-type-advanced-contract
              :id "FR-1501" :semantic-domain :safety
              :property-predicates '((:absent-property . consp))))
            :to-be node)
    ;; requires-evidence-p with no evidence on the node signals.
    (signals error
        (%type-advanced-validate-contract
         node
         (make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :requires-evidence-p t)))
    (let ((evidenced (make-type-advanced :feature-id "FR-1501"
                                                     :args (list type-int)
                                                     :evidence 42)))
      ;; requires-evidence-p is satisfied once evidence is present.
      (expect (%type-advanced-validate-contract
               evidenced
               (make-type-advanced-contract
                :id "FR-1501" :semantic-domain :safety :requires-evidence-p t))
              :to-be evidenced)
      ;; An evidence-predicate that accepts the evidence value passes.
      (expect (%type-advanced-validate-contract
               evidenced
               (make-type-advanced-contract
                :id "FR-1501" :semantic-domain :safety :evidence-predicate 'integerp))
              :to-be evidenced)
      ;; An evidence-predicate that rejects the evidence value signals.
      (signals error
          (%type-advanced-validate-contract
           evidenced
           (make-type-advanced-contract
            :id "FR-1501" :semantic-domain :safety :evidence-predicate 'stringp)))
      ;; With no evidence on the node at all, an evidence-predicate is never
      ;; consulted, so it does not by itself force evidence to be present.
      (expect (%type-advanced-validate-contract
               node
               (make-type-advanced-contract
                :id "FR-1501" :semantic-domain :safety :evidence-predicate 'stringp))
              :to-be node))))

(it-sequential "validate-type-advanced-rejects-non-nodes-and-unregistered-feature-ids-directly"
  ;; A non-type-advanced value is rejected before any registry lookup runs.
  (signals error (validate-type-advanced 42))
  ;; A well-formed struct whose feature id was never registered is rejected
  ;; by validate-type-advanced's own registry check, distinct from (and
  ;; reached before) %type-advanced-validate-by-feature's missing-contract
  ;; check exercised below.
  (let ((node (%make-type-advanced :feature-id "FR-9999-NEVER-REGISTERED"
                                                :name 'advanced :args nil
                                                :properties nil :evidence nil)))
    (signals error (validate-type-advanced node))
    ;; type-advanced-valid-p wraps both failure modes in a handler-case and
    ;; reports them as a plain NIL rather than propagating the error.
    (expect (type-advanced-valid-p node) :to-be-falsy))
  (expect (type-advanced-valid-p 42) :to-be-falsy))

(it-sequential "type-advanced-validate-by-feature-signals-when-no-explicit-contract-is-registered"
  ;; %type-advanced-validate-by-feature only consults the contract registry
  ;; (unlike validate-type-advanced, it never checks the feature registry),
  ;; so calling it directly on a feature id with no registered contract
  ;; reaches its own "no semantic contract is implemented" branch, even
  ;; though every id reachable through the public API always has one thanks
  ;; to %ensure-type-advanced-contract-coverage.
  (let ((node (%make-type-advanced :feature-id "FR-9999-NO-CONTRACT-REGISTERED"
                                                :name 'advanced :args nil
                                                :properties nil :evidence nil)))
    (signals error (%type-advanced-validate-by-feature node))))

(defun %unvalidated-advanced-node (feature-id &key (name 'advanced) args properties evidence)
  (%make-type-advanced :feature-id feature-id
                       :name name
                       :args args
                       :properties properties
                       :evidence evidence))

(it-sequential "advanced-validate-brand-fr-3205-requires-a-symbolic-or-string-brand-name"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-3205" :name 'brand-type
                                   :args (list 42 type-int))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-3205" :name 'brand-type
                                :args (list 'user-id type-int)))
   :to-be-truthy)
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-3205" :name 'brand-type
                                :args (list "UserId" type-int)))
   :to-be-truthy))

(it-sequential "advanced-validate-synthesis-fr-3003-requires-evidence-for-proof-search-strategy"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-3003"
        :args (list '(-> integer integer))
        :properties '((:search . :proof-search) (:fuel . 8)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-3003"
     :args (list '(-> integer integer))
     :properties '((:search . :proof-search) (:fuel . 8))
     :evidence '(proof search-goal)))
   :to-be-truthy))

(it-sequential "advanced-validate-mapped-types-fr-3301-checks-base-and-filter-shapes"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-3301" :name 'mapped-type
                                   :args (list 42)
                                   :properties '((:transform . optional)))))
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-3301" :name 'mapped-type
                                   :args (list '(list fixnum))
                                   :properties '((:transform . optional)
                                                 (:filter . 42)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-3301" :name 'mapped-type
                                :args (list '(list fixnum))
                                :properties '((:transform . optional)
                                              (:filter . evenp))))
   :to-be-truthy))

(it-sequential "advanced-validate-type-theory-equality-fr-3405-checks-intensional-payload-equality"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-3405" :name 'type-theory-equality
                                   :args (list type-int type-string)
                                   :properties '((:mode . :intensional)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-3405" :name 'type-theory-equality
                                :args (list type-int type-int)
                                :properties '((:mode . :intensional))))
   :to-be-truthy))

(it-sequential "advanced-validate-staging-fr-1703-checks-quote-transition-and-run-stage-mismatch"
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-1703"
                                :args (list '(quote integer))
                                :properties '((:stage . 0) (:transition . :quote))))
   :to-be-truthy)
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-1703"
                                   :args (list '(code integer))
                                   :properties '((:stage . 0) (:transition . :run))
                                   :evidence '(proof staged-eval)))))

(it-sequential "advanced-validate-staging-fr-1703-accepts-a-bare-type-node-payload"
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-1703"
                                :args (list type-int)
                                :properties '((:stage . 1) (:transition . :quote))))
   :to-be-truthy))

(it-sequential "advanced-validate-staging-fr-1703-rejects-a-payload-that-is-neither-shape"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-1703"
                                   :args (list 42)
                                   :properties '((:stage . 1) (:transition . :quote))))))

(it-sequential "advanced-validate-alias-analysis-fr-2902-rejects-non-pointer-operands"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-2902"
        :args (list 'not-a-pointer '(pointer integer))
        :properties '((:disjoint . nil) (:alias-class . heap)))))
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-2902"
        :args (list '(pointer integer) 'not-a-pointer)
        :properties '((:disjoint . nil) (:alias-class . heap))))))

(it-sequential "advanced-validate-smt-integration-fr-2406-accepts-a-counterexample-in-place-of-evidence"
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-2406"
     :args (list '(< v n))
     :properties '((:solver . :z3) (:theory . :lia)
                   (:counterexample . (v -1)))))
   :to-be-truthy))

(it-sequential "advanced-validate-smt-integration-fr-2406-rejects-neither-evidence-nor-counterexample"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-2406"
        :args (list '(< v n))
        :properties '((:solver . :z3) (:theory . :lia))))))

(it-sequential "advanced-validate-incremental-checking-fr-1606-rejects-identical-graph-and-cache"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-1606"
        :args '(cache-entry)
        :properties '((:dependency-graph . same-thing)
                      (:cache . same-thing))))))

(it-sequential "advanced-validate-test-generation-fr-2101-rejects-samples-over-coverage-target"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-2101"
        :args '(some-generator)
        :properties '((:generator . (arbitrary integer))
                      (:coverage-target . 10)
                      (:samples . 20)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-2101"
     :args '(some-generator)
     :properties '((:generator . (arbitrary integer))
                   (:coverage-target . 10)
                   (:samples . 5))))
   :to-be-truthy))

(it-sequential "advanced-validate-abstract-interpretation-fr-2804-rejects-identical-widening-and-narrowing"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-2804"
        :args '(some-domain)
        :properties '((:domain . interval)
                      (:widening . same-op)
                      (:narrowing . same-op)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-2804"
     :args '(some-domain)
     :properties '((:domain . interval)
                   (:widening . widen-op)
                   (:narrowing . narrow-op))))
   :to-be-truthy)
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-2804"
     :args '(some-domain)
     :properties '((:domain . interval)
                   (:widening . widen-op))))
   :to-be-truthy))

(it-sequential "advanced-validate-plugins-fr-3002-rejects-a-non-symbolic-plugin-name"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-3002"
        :args '(42)
        :properties '((:hook . my-hook) (:phase . :solve))))))

(it-sequential "advanced-validate-encodings-fr-3403-rejects-a-surface-head-mismatched-with-the-encoding-property"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-3403" :name 'scott-encoding
        :args '(some-payload)
        :properties '((:encoding . :church)))))
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node
        "FR-3403" :name 'parigot-encoding
        :args '(some-payload)
        :properties '((:encoding . :scott)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-3403" :name 'scott-encoding
     :args '(some-payload)
     :properties '((:encoding . :scott))))
   :to-be-truthy))

(it-sequential "advanced-validate-encodings-fr-3403-skips-the-head-check-for-the-generic-advanced-form"
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node
     "FR-3403" :name 'advanced
     :args '(some-payload)
     :properties '((:encoding . :church))))
   :to-be-truthy))

(it-sequential "advanced-validate-type-theory-equality-fr-3405-requires-evidence-for-extensional-and-observational-modes"
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-3405" :name 'type-theory-equality
                                   :args (list type-int type-int)
                                   :properties '((:mode . :extensional)))))
  (signals error
      (validate-type-advanced
       (%unvalidated-advanced-node "FR-3405" :name 'type-theory-equality
                                   :args (list type-int type-int)
                                   :properties '((:mode . :observational)))))
  (expect
   (type-advanced-valid-p
    (%unvalidated-advanced-node "FR-3405" :name 'type-theory-equality
                                :args (list type-int type-int)
                                :properties '((:mode . :extensional))
                                :evidence '(bisimulation proof)))
   :to-be-truthy))
