;;;; types-extended-advanced-evidence-data.lisp — Implementation evidence table
;;;; Extracted from types-extended-advanced-data.lisp.
;;;; Load order: after types-extended-advanced-data.
(in-package :cl-cc/type/advanced-metadata)

(defparameter +type-advanced-implementation-evidence-specs+
  (append
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-1501"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp")
     '(parse-type-specifier type-union-p type-union-types)
     '(parse-option-type))
    (%type-advanced-implementation-evidence-spec
     "FR-1502"
     '("src/concurrency/types-extended-concurrency.lisp")
     '(register-concurrency-traits sendable-type-p shareable-type-p validate-spawn-argument
       validate-shared-reference)
     '(concurrency-send-sync-registry-is-concrete))
    (%type-advanced-implementation-evidence-spec
     "FR-1503"
     '("src/security-labels/types-extended-security-labels.lisp")
     '(type-advanced-security-label<= make-labeled-value sanitize-labeled-value
       declassify-labeled-value labeled-value-flow-allowed-p)
     '(security-label-lattice-and-declassification-are-enforced advanced-validate-information-flow-fr-1503-checks-target-rank-and-declassification-evidence))
    (%type-advanced-implementation-evidence-spec
     "FR-1504"
     '("src/regions/types-extended-regions.lisp")
     '(with-region region-alloc region-ref-valid-p region-deref)
     '(region-tokens-enforce-lifetimes))
    (%type-advanced-implementation-evidence-spec
     "FR-1505"
     '("src/capabilities/types-extended-capabilities.lisp")
     '(make-capability restrict-capability capability-allows-p capability-implies-p
       capability-effects)
     '(capabilities-support-implication-restriction-and-effects)))
   (list
    (%type-advanced-implementation-evidence-spec "FR-1601" '("src/inference/inference-handlers.lisp" "src/type-model/inference-conditions.lisp") '(infer typed-hole-error type-inference-error type-inference-error-message) '(infer-ast-hole-signals-typed-hole-error infer-typed-hole-signals-error infer-typed-hole-message-names-in-scope-vars typed-hole-error-message-lists-available-bindings typed-hole-error-message-formats-a-binding-whose-value-is-a-bare-type-not-a-scheme))
    (%type-advanced-implementation-evidence-spec "FR-1603" '("src/inference/inference-effects.lisp" "src/effects/effect.lisp") '(infer-effects infer-with-effects check-body-effects register-effect-signature lookup-effect-signature effect-row-union effect-row-subset-p) '(infer-effects-single-forms infer-effects-multi-form-unions infer-with-effects-returns-triple infer-check-body-effects-io-row-succeeds infer-check-body-effects-pure-row-signals-error infer-with-effects-returns-type-subst-and-effects infer-effects-print-is-io infer-effects-setq-is-state infer-effects-if-unions-cond-then-else infer-effects-let-unions-bindings-and-body infer-effects-progn-and-block-union-forms infer-effects-call-uses-registered-effect-signature check-body-effects-accepts-declared-superset-and-rejects-undeclared))
    (%type-advanced-implementation-evidence-spec "FR-1604" '("src/inference/inference-forms.lisp" "src/unification/substitution-schemes.lisp") '(infer-let syntactic-value-p generalize) '(infer-syntactic-value-p-truthy infer-syntactic-value-p-falsy infer-value-restriction-lambda-binding-generalizes infer-value-restriction-call-binding-stays-monomorphic infer-ast-let-generalizes-syntactic-values infer-ast-let-keeps-applications-monomorphic))
    (%type-advanced-implementation-evidence-spec "FR-1605" '("src/type-model/inference-conditions.lisp" "src/inference/inference-handlers.lisp") '(type-inference-error type-inference-error-message typed-hole-error unbound-variable-error unbound-variable-error-name type-mismatch-error type-mismatch-error-expected type-mismatch-error-actual) '(infer-condition-type-mismatch-carries-expected-and-actual infer-condition-unbound-variable-carries-name infer-condition-base-error-has-message infer-typed-hole-message-names-in-scope-vars typed-hole-error-message-lists-available-bindings typed-hole-error-message-formats-a-binding-whose-value-is-a-bare-type-not-a-scheme)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-1602"
     '("src/generics/generics.lisp")
     '(register-generic-instance lookup-generic-instance generic-representation-of generic-show
       generic-transform generic-query generic-representation-valid-p)
     '(concrete-generics-registry-and-structural-traversal-work)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-1606"
     '("src/type-model/types-extended-nodes.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(make-type-advanced validate-type-advanced %type-advanced-validate-incremental-checking)
     '(advanced-contracts-enforce-incremental-staging-optics-and-test-generation advanced-validate-incremental-checking-fr-1606-rejects-identical-graph-and-cache)))
   (append
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-1701"
     '("src/type-level/types-level-naturals.lisp" "src/type-level/types-level-strings.lisp" "src/type-model/types-extended-nodes.lisp")
     '(make-type-level-natural type-level-natural-value make-type-level-string template-literal-type)
     '(type-level-constructors-cover-static-nats-strings-vectors-and-matrices))
    (%type-advanced-implementation-evidence-spec
     "FR-1702"
     '("src/type-level/types-level-naturals.lisp" "src/type-level/types-level-strings.lisp" "src/type-model/types-extended-nodes.lisp")
     '(make-type-level-natural type-level-natural-value make-type-level-string template-literal-type)
     '(type-level-constructors-cover-static-nats-strings-vectors-and-matrices)))
   (%type-advanced-implementation-evidence-specs
    '("FR-1704" "FR-1705")
    '("src/type-level/types-level-naturals.lisp" "src/type-level/types-level-strings.lisp" "src/type-model/types-extended-nodes.lisp")
    '(make-type-level-natural type-level-natural-value make-type-level-string template-literal-type)
    '(concrete-utility-type-helpers-operate-on-nats-strings-and-record-transforms advanced-feature-implementation-evidence-covers-all-fr-ids)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-1703"
     '("src/type-model/types-extended-nodes.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(make-type-advanced validate-type-advanced %type-advanced-validate-staging)
     '(advanced-contracts-enforce-incremental-staging-optics-and-test-generation advanced-validate-staging-fr-1703-checks-quote-transition-and-run-stage-mismatch)))
   (append
   (list
    (%type-advanced-implementation-evidence-spec "FR-1802" '("src/hlist/types-hlist.lisp" "src/inference/inference-formatting.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/type-model/types-extended-nodes.lisp") '(make-hlist-type hlist-head-type hlist-tail-type format-type parse-type-specifier) '(concrete-utility-type-helpers-operate-on-nats-strings-and-record-transforms advanced-feature-parser-roundtrips))
    (%type-advanced-implementation-evidence-spec
     "FR-1803"
     '("src/hlist/types-hlist.lisp" "src/inference/inference-formatting.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/type-model/types-extended-nodes.lisp")
     '(make-hlist-type hlist-head-type hlist-tail-type format-type parse-type-specifier)
     '(hlist-type-family-builds-heads-tails-and-rejects-non-type-elements))
    (%type-advanced-implementation-evidence-spec
     "FR-1804"
     '("src/hlist/types-hlist.lisp" "src/inference/inference-formatting.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/type-model/types-extended-nodes.lisp")
     '(make-hlist-type hlist-head-type hlist-tail-type format-type parse-type-specifier)
     '(format-type-returns-an-arrow-with-argument-parameters)))
   (%type-advanced-implementation-evidence-specs
    '("FR-1805" "FR-1806")
    '("src/hlist/types-hlist.lisp" "src/inference/inference-formatting.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/type-model/types-extended-nodes.lisp")
    '(make-hlist-type hlist-head-type hlist-tail-type format-type parse-type-specifier)
    '(concrete-utility-type-helpers-operate-on-nats-strings-and-record-transforms advanced-feature-parser-roundtrips)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-1801"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-optics)
     '(advanced-contracts-enforce-incremental-staging-optics-and-test-generation)))
   (%type-advanced-implementation-evidence-specs
    '("FR-1901" "FR-1902" "FR-1903" "FR-1904" "FR-1905" "FR-1906")
    '("src/dependent/types-extended-dependent.lisp")
    '(make-termination-evidence termination-evidence-valid-p make-proof-evidence
      verify-proof-obligation verify-proof-evidence)
    '(termination-and-pcc-evidence-check-real-obligations
      advanced-validators-now-use-concrete-semantic-modules))
   (append
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2001"
     '("src/dependent/types-extended-dependent.lisp")
     '(make-proof-carrying-code verify-proof-carrying-code make-proof-evidence verify-proof-evidence)
     '(advanced-validate-proof-like-accepts-well-formed-termination-and-curry-howard-evidence))
    (%type-advanced-implementation-evidence-spec
     "FR-2002"
     '("src/dependent/types-extended-dependent.lisp")
     '(make-proof-carrying-code verify-proof-carrying-code make-proof-evidence verify-proof-evidence)
     '(termination-and-pcc-evidence-check-real-obligations)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2003" "FR-2004" "FR-2005")
    '("src/dependent/types-extended-dependent.lisp")
    '(make-proof-carrying-code verify-proof-carrying-code make-proof-evidence verify-proof-evidence)
    '(advanced-proof-like-features-require-evidence termination-and-pcc-evidence-check-real-obligations)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2102" "FR-2104" "FR-2105" "FR-2106" "FR-2107")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2101"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-test-generation)
     '(advanced-contracts-enforce-incremental-staging-optics-and-test-generation advanced-validate-test-generation-fr-2101-rejects-samples-over-coverage-target))
    (%type-advanced-implementation-evidence-spec
     "FR-2103"
     '("src/ffi/types-extended-ffi.lisp")
     '(make-ffi-scalar-type make-ffi-pointer-type make-ffi-callback-type
       make-ffi-function-descriptor ffi-type-valid-p)
     '(advanced-validate-type-safe-ffi-fr-2103-checks-raw-descriptor-form-shape ffi-descriptors-validate-recursively)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2201"
     '("src/inference/inference-forms-advanced.lisp")
     '(%advanced-call-future-return)
     '(advanced-call-spawn-enforces-send-boundary
       advanced-infer-spawn-enforces-send-and-returns-future))
    (%type-advanced-implementation-evidence-spec
     "FR-2202"
     '("src/channels/channels.lisp")
     '(make-typed-channel channel-send channel-recv close-typed-channel)
     '(concrete-channels-enforce-capacity-type-and-close-semantics))
    (%type-advanced-implementation-evidence-spec
     "FR-2203"
     '("src/actors/actors.lisp")
     '(make-actor-ref actor-message-accepted-p actor-send actor-stop)
     '(concrete-actors-accept-typed-messages-and-stop-cleanly))
    (%type-advanced-implementation-evidence-spec
     "FR-2204"
     '("src/stm/stm.lisp")
     '(make-tvar stm-read stm-write stm-bind atomically)
     '(concrete-stm-actions-sequence-and-reject-io-effects))
    (%type-advanced-implementation-evidence-spec
     "FR-2205"
     '("src/coroutines/coroutines.lisp")
     '(make-generator generator-next make-coroutine coroutine-resume)
     '(concrete-coroutines-generators-and-coroutines-enforce-runtime-types))
    (%type-advanced-implementation-evidence-spec
     "FR-2206"
     '("src/simd/simd.lisp")
     '(make-simd-vector simd-map simd-add)
     '(concrete-simd-vectors-preserve-lanes-and-element-types)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2301" "FR-2303" "FR-2304" "FR-2305")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2302"
     '("src/units/types-extended-units.lisp")
     '(make-measure measure+ measure/ convert-unit unit-compatible-p)
     '(units-of-measure-perform-dimension-checking advanced-units-validator-rejects-an-unknown-unit)))
   (append
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2401"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/unification/unification.lisp")
     '(type-unify parse-type-specifier validate-type-advanced)
     '(unify-advanced-same-feature-succeeds unify-advanced-different-feature-id-fails))
    (%type-advanced-implementation-evidence-spec
     "FR-2402"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/unification/unification.lisp")
     '(type-unify parse-type-specifier validate-type-advanced)
     '(bidirectional-check-against-forall-checks-the-skolemized-body)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2403" "FR-2404")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/unification/unification.lisp")
    '(type-unify parse-type-specifier validate-type-advanced)
    '(advanced-node-unification-is-structural-and-fr-scoped advanced-feature-parser-roundtrips)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2405"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-meta-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-interface-export-list-p)
     '(advanced-contracts-enforce-constraint-analysis-and-tooling-families advanced-interface-export-list-p-validates-entry-shapes-and-name-uniqueness))
    (%type-advanced-implementation-evidence-spec
     "FR-2406"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-smt-integration)
     '(advanced-contracts-enforce-constraint-analysis-and-tooling-families advanced-validate-smt-integration-fr-2406-accepts-a-counterexample-in-place-of-evidence)))
   (list
    (%type-advanced-implementation-evidence-spec "FR-2503"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
     '(parse-type-specifier make-type-advanced type-advanced-valid-p)
     '(advanced-feature-parser-roundtrips advanced-feature-implementation-evidence-covers-all-fr-ids))
    (%type-advanced-implementation-evidence-spec
     "FR-2504"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
     '(parse-type-specifier make-type-advanced type-advanced-valid-p)
     '(infer-ast-if-narrows-union-type-via-type-guard))
    (%type-advanced-implementation-evidence-spec "FR-2505"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
     '(parse-type-specifier make-type-advanced type-advanced-valid-p)
     '(advanced-feature-parser-roundtrips advanced-feature-implementation-evidence-covers-all-fr-ids)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2501"
     '("src/type-model/types-extended-nodes.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/unification/unification.lisp")
     '(make-type-dynamic make-type-advanced type-unify)
     '(make-type-dynamic-and-make-type-type-rep-build-valid-fr-2501-and-fr-2502-nodes))
    (%type-advanced-implementation-evidence-spec
     "FR-2502"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
     '(make-type-type-rep parse-type-specifier validate-type-advanced)
     '(make-type-dynamic-and-make-type-type-rep-build-valid-fr-2501-and-fr-2502-nodes)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2601" "FR-2602" "FR-2604" "FR-2605" "FR-2606")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced type-advanced-valid-p)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2603"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
     '(parse-type-specifier make-type-advanced validate-type-advanced)
     '(advanced-feature-parser-roundtrips
       advanced-feature-implementation-evidence-covers-all-fr-ids)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2701" "FR-2702" "FR-2703" "FR-2704" "FR-2705" "FR-2706")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (%type-advanced-implementation-evidence-specs
    '("FR-2801" "FR-2802" "FR-2803" "FR-2805")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2804"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-abstract-interpretation)
     '(advanced-contracts-enforce-constraint-analysis-and-tooling-families advanced-validate-abstract-interpretation-fr-2804-rejects-identical-widening-and-narrowing)))
   (%type-advanced-implementation-evidence-specs
    '("FR-2901" "FR-2903" "FR-2904" "FR-2905")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-2902"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-alias-analysis)
     '(advanced-contracts-enforce-constraint-analysis-and-tooling-families advanced-validate-alias-analysis-fr-2902-rejects-non-pointer-operands)))
   (%type-advanced-implementation-evidence-specs
    '("FR-3001" "FR-3004" "FR-3005")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-3002"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-plugins)
     '(advanced-contracts-enforce-constraint-analysis-and-tooling-families advanced-validate-plugins-fr-3002-rejects-a-non-symbolic-plugin-name))
    (%type-advanced-implementation-evidence-spec
     "FR-3003"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-synthesis)
     '(advanced-contracts-enforce-constraint-analysis-and-tooling-families advanced-validate-synthesis-fr-3003-requires-evidence-for-proof-search-strategy)))
   (%type-advanced-implementation-evidence-specs
    '("FR-3102" "FR-3103" "FR-3104")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
     '(advanced-feature-parser-roundtrips
       advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-3101"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
     '(parse-type-specifier make-type-advanced validate-type-advanced)
     '(advanced-feature-parser-roundtrips
       advanced-feature-implementation-evidence-covers-all-fr-ids)))
   (%type-advanced-implementation-evidence-specs
    '("FR-3201" "FR-3202" "FR-3203" "FR-3204")
    '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-init.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp")
    '(parse-type-specifier make-type-advanced validate-type-advanced)
    '(advanced-feature-parser-roundtrips
      advanced-feature-implementation-evidence-covers-all-fr-ids))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-3205"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-brand)
     '(advanced-validate-brand-fr-3205-requires-a-symbolic-or-string-brand-name)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-3301"
     '("src/utility-types/types-utility.lisp" "src/inference/inference-formatting.lisp" "src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(readonly-type partial-type required-type pick-type omit-type exclude-type extract-type non-nullable-type return-type-of)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality advanced-validate-mapped-types-fr-3301-checks-base-and-filter-shapes parser-associates-feature-ids-with-structural-and-equality-heads))
    (%type-advanced-implementation-evidence-spec
     "FR-3302"
     '("src/utility-types/types-utility.lisp" "src/inference/inference-formatting.lisp" "src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(readonly-type partial-type required-type pick-type omit-type exclude-type extract-type non-nullable-type return-type-of)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality parser-associates-feature-ids-with-structural-and-equality-heads))
    (%type-advanced-implementation-evidence-spec
     "FR-3303"
     '("src/utility-types/types-utility.lisp" "src/inference/inference-formatting.lisp" "src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(readonly-type partial-type required-type pick-type omit-type exclude-type extract-type non-nullable-type return-type-of)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality types-utility-family-covers-writable-deep-readonly-pick-omit-exclude-extract utility-types-compose-with-field-requirements-and-freeze))
    (%type-advanced-implementation-evidence-spec
     "FR-3304"
     '("src/utility-types/types-utility.lisp" "src/inference/inference-formatting.lisp" "src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(readonly-type partial-type required-type pick-type omit-type exclude-type extract-type non-nullable-type return-type-of)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality types-utility-family-covers-writable-deep-readonly-pick-omit-exclude-extract utility-types-compose-with-field-requirements-and-freeze)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-3305"
     '("src/routing/routing.lisp" "src/routing/types-extended-routing-types.lisp")
     '(make-api-type api-route-lookup route-response-type-for make-route build-route-path
       match-route-path)
     '(routing-validates-path-parameters-and-roundtrips
      concrete-routing-api-lookup-and-response-type-work)))
   (list
    (%type-advanced-implementation-evidence-spec
     "FR-3401"
     '("src/quantities/types-extended-qtt.lisp")
     '(make-qtt-semiring make-graded-value make-qtt-binding valid-multiplicity-p qtt-erased-p)
     '(qtt-and-graded-semantics-check-semiring-behavior
      advanced-contracts-enforce-typescript-encodings-effects-and-equality))
    (%type-advanced-implementation-evidence-spec
     "FR-3402"
     '("src/quantities/types-extended-qtt.lisp")
     '(make-graded-value graded-add graded-compose valid-multiplicity-p)
     '(qtt-and-graded-semantics-check-semiring-behavior advanced-contracts-enforce-typescript-encodings-effects-and-equality))
    (%type-advanced-implementation-evidence-spec
     "FR-3403"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-encodings)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality parser-preserves-encoding-surface-head-and-property-fields advanced-validate-encodings-fr-3403-rejects-a-surface-head-mismatched-with-the-encoding-property))
    (%type-advanced-implementation-evidence-spec
     "FR-3404"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-extensible-effects)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality parser-associates-feature-ids-with-structural-and-equality-heads))
    (%type-advanced-implementation-evidence-spec
     "FR-3405"
     '("src/type-model/types-extended-nodes.lisp" "src/syntax/protocol.lisp" "src/type-lowering/parser.lisp" "src/advanced-metadata/types-extended-advanced-validate.lisp" "src/advanced-metadata/types-extended-advanced-validators.lisp")
     '(parse-type-specifier validate-type-advanced %type-advanced-validate-type-theory-equality)
     '(advanced-contracts-enforce-typescript-encodings-effects-and-equality advanced-validate-type-theory-equality-fr-3405-checks-intensional-payload-equality))
    (%type-advanced-implementation-evidence-spec
     "FR-3406"
     '("src/dependent/types-extended-dependent.lisp")
     '(make-universe-sort universe<= make-cic-proposition make-cic-proof cic-proof-valid-p
       proof-erasable-p)
     '(cic-scaffolding-validates-universes-and-proof-erasure))))
  "Concrete helper-API and regression-test evidence for every tracked advanced FR id.")
