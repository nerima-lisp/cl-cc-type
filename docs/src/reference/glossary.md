# Glossary

Key types and functions are representative public symbols, not a complete API
list. `None` means no representative is listed for that entry.

## type-model

- Definition: Defines the shared kinds, type nodes, type schemes, type environments, equality, and common node rendering used by type-system features.
- Package: `cl-cc/type/type-model`
- Key types: `type-node`, `type-primitive`
- Key functions: `make-type-primitive`, `make-type-arrow`, `type-equal-p`
- Other contexts: Feature packages depend on this shared model. Parser and rendering protocols live in `syntax`; parsing implementations live in `type-lowering`.

## registries

- Definition: Stores shared type-system registrations and provides lookup APIs for aliases, interfaces, and advanced feature metadata.
- Package: `cl-cc/type/registries`
- Key types: `type-interface-module`
- Key functions: `lookup-type-interface`, `register-type-alias`, `lookup-type-alias`
- Other contexts: `type-lowering` parses interface specifiers before passing normalized nodes to the registry data API.

## quantities

- Definition: Models multiplicity and quantity-aware type operations, including graded values and QTT bindings.
- Package: `cl-cc/type/quantities`
- Key types: `qtt-binding`, `graded-value`
- Key functions: `multiplicity+`, `normalize-multiplicity`, `graded-compose`
- Other contexts: Surface syntax is parsed by `type-lowering`; shared advanced metadata owns the validator and normalizer callback registries.

## type-level

- Definition: Provides natural-number and string operations used to construct type-level literals, vectors, matrices, and templates.
- Package: `cl-cc/type/type-level`
- Key types: None.
- Key functions: `make-type-level-natural`, `make-type-level-string`, `type-plus`, `make-matrix-type`, `template-literal-type`
- Other contexts: It depends on the shared type model and advanced metadata. General utility types are owned by `utility-types`.

## hlist

- Definition: Describes heterogeneous list types and operations that expose their head and tail types.
- Package: `cl-cc/type/hlist`
- Key types: None.
- Key functions: `make-hlist-type`, `hlist-head-type`, `hlist-tail-type`
- Other contexts: Hlist type operations use the shared type model and advanced metadata.

## rows

- Definition: Provides record and variant row operations for extending, selecting, restricting, and inspecting row labels.
- Package: `cl-cc/type/rows`
- Key types: None.
- Key functions: `row-extend`, `row-select`, `row-restrict`
- Other contexts: Row node representations are defined in `type-model`. Effect-row operations are owned by `effects`.

## effects

- Definition: Defines effect declarations, signatures, and effect-row operations used by inference.
- Package: `cl-cc/type/effects`
- Key types: `effect-def`
- Key functions: `register-effect`, `effect-row-union`
- Other contexts: Effect nodes are defined in `type-model`; row structure operations are owned by `rows`. AST effect inference and signature integration live in `inference`.

## subtyping

- Definition: Implements the node-level subtype relation, joins and meets, and protocol and class-shape registries.
- Package: `cl-cc/type/subtyping`
- Key types: None.
- Key functions: `is-subtype-p`, `type-join`, `type-meet`
- Other contexts: Type-specifier adapters are owned by `type-lowering`. This feature uses effect, registry, and security-label APIs.

## syntax

- Definition: Defines dependency-free generic protocols for parsing and rendering type representations.
- Package: `cl-cc/type/syntax`
- Key types: None.
- Key functions: `parse-type-specifier`, `type-to-string`, `unparse-type`
- Other contexts: `type-lowering` implements parsing and recognition; model and domain features implement rendering methods.

## type-lowering

- Definition: Converts surface type specifiers into semantic nodes and provides parser-facing compatibility adapters.
- Package: `cl-cc/type/type-lowering`
- Key types: `type-parse-error`
- Key functions: `parse-compound-type`, `parse-typed-defun`, `register-type-interface`
- Other contexts: Parsing depends on model, registry, quantity, advanced-metadata, and subtyping APIs. The parser-neutral generic contracts are owned by `syntax`.

## unification

- Definition: Solves type constraints and manages substitutions, normalization, and unification across type nodes.
- Package: `cl-cc/type/unification`
- Key types: `constraint`, `substitution`
- Key functions: `type-unify`, `solve-constraints`, `zonk`
- Other contexts: Type-class constraints are dispatched through a resolver registered by `type-classes`, keeping the dependency one-way.

## type-classes

- Definition: Defines type classes and instances, checks class constraints, and registers the type-class constraint resolver.
- Package: `cl-cc/type/type-classes`
- Key types: `typeclass-def`, `typeclass-instance`
- Key functions: `register-typeclass`, `register-typeclass-instance`, `check-typeclass-constraint`
- Other contexts: Instance overlap checks use `unification`; the solver does not call back into this feature.

## inference

- Definition: Infers types and effects for compiler ASTs, including advanced forms and class, alias, and predicate registrations.
- Package: `cl-cc/type/inference`
- Key types: `advanced-call-policy`
- Key functions: `infer`, `infer-with-env`, `infer-with-constraints`, `infer-effects`, `validate-advanced-call`
- Other contexts: Inference depends on parsing, unification, type classes, effects, subtyping, and runtime type features. Class-shape and alias storage live in `subtyping` and `registries`.

## checking

- Definition: Provides bidirectional synthesis, checking, body checks, and skolem-escape validation.
- Package: `cl-cc/type/checking`
- Key types: None.
- Key functions: `synthesize`, `check`, `check-skolem-escape`
- Other contexts: Checking builds on inference, unification, the shared model, and the syntax protocol.

## exhaustiveness

- Definition: Checks whether typecase and etypecase branches cover the relevant type space.
- Package: `cl-cc/type/exhaustiveness`
- Key types: None.
- Key functions: `check-typecase-exhaustiveness`, `check-etypecase-completeness`
- Other contexts: Exhaustiveness analysis uses the subtype relation from `subtyping`.

## utility-types

- Definition: Builds reusable readonly, writable, partial, required, selection, exclusion, nullability, return, and freeze type transformations.
- Package: `cl-cc/type/utility-types`
- Key types: `frozen-value`
- Key functions: `readonly-type`, `partial-type`, `return-type-of`
- Other contexts: Field-name comparison is private to this feature; type-level literal and template operations belong to `type-level`.

## generics

- Definition: Represents datatype-generic structure and provides generic representation, traversal, display, transformation, and query operations.
- Package: `cl-cc/type/generics`
- Key types: `generic-instance`, `generic-product`
- Key functions: `generic-show`, `generic-transform`, `generic-query`
- Other contexts: Generic representation registration is local to this feature.

## channels

- Definition: Provides typed channels and converts runtime channel operations into type-level forms.
- Package: `cl-cc/type/channels`
- Key types: `typed-channel`
- Key functions: `make-typed-channel`, `channel-send`, `channel-recv`
- Other contexts: Runtime type matching uses the shared internal `ANY` sentinel from `type-model`.

## actors

- Definition: Models typed actor references and validates message sends against an actor's declared message type.
- Package: `cl-cc/type/actors`
- Key types: `typed-actor-ref`
- Key functions: `make-actor-ref`, `actor-send`, `actor-stop`
- Other contexts: Actor type checks use the shared `ANY` sentinel from `type-model` and local runtime-matching helpers.

## coroutines

- Definition: Models typed generators and coroutines, including yield, send, receive, and completion behavior.
- Package: `cl-cc/type/coroutines`
- Key types: `typed-generator`, `typed-coroutine`
- Key functions: `make-generator`, `generator-next`, `coroutine-resume`
- Other contexts: Coroutine type checks use the shared `ANY` sentinel from `type-model` and local runtime-matching helpers.

## stm

- Definition: Models software transactional memory variables and typed transaction actions.
- Package: `cl-cc/type/stm`
- Key types: `tvar`, `stm-action`
- Key functions: `atomically`, `stm-read`, `stm-write`
- Other contexts: STM type checks use the shared `ANY` sentinel from `type-model` and local runtime-matching helpers.

## simd

- Definition: Models SIMD vectors and typed vector construction, mapping, and addition.
- Package: `cl-cc/type/simd`
- Key types: `simd-vector`
- Key functions: `make-simd-vector`, `simd-map`, `simd-add`
- Other contexts: SIMD type checks use the shared `ANY` sentinel from `type-model` and local runtime-matching helpers.

## routing

- Definition: Models typed routes and API specifications, validates route forms, and matches path templates.
- Package: `cl-cc/type/routing`
- Key types: `route`, `api-spec`
- Key functions: `make-route`, `match-route-path`, `route-form-valid-p`
- Other contexts: Surface route parsing belongs to `type-lowering`; route validation registers through `advanced-metadata`.

## capabilities

- Definition: Models capability values, permissions, restriction, implication, and associated type effects.
- Package: `cl-cc/type/capabilities`
- Key types: `capability`
- Key functions: `make-capability`, `capability-allows-p`, `restrict-capability`
- Other contexts: Capability operations are independent of the shared type model.

## concurrency

- Definition: Describes sendability, shareability, and concurrency traits for typed values, and validates spawn and shared-reference use.
- Package: `cl-cc/type/concurrency`
- Key types: `concurrency-traits`
- Key functions: `register-concurrency-traits`, `sendable-type-p`, `validate-spawn-argument`
- Other contexts: Concurrency trait definitions and spawn/shared-reference checks are handled in this feature.

## dependent

- Definition: Models universes, propositions, proofs, inductive types, termination evidence, and proof-carrying code.
- Package: `cl-cc/type/dependent`
- Key types: `cic-proof`, `proof-evidence`
- Key functions: `cic-proof-valid-p`, `termination-evidence-valid-p`, `verify-proof-carrying-code`
- Other contexts: Dependent-proof validation registers with `advanced-metadata`.

## ffi

- Definition: Describes FFI scalar, pointer, callback, and function types and validates their compatibility with Lisp types.
- Package: `cl-cc/type/ffi`
- Key types: `ffi-function-descriptor`, `ffi-pointer-type`
- Key functions: `make-ffi-function-descriptor`, `ffi-type-valid-p`, `ffi-descriptor-form-valid-p`
- Other contexts: FFI validator callbacks are registered with `advanced-metadata`.

## regions

- Definition: Tracks region lifetimes and references, validates active allocations, and provides scoped region operations.
- Package: `cl-cc/type/regions`
- Key types: `region-token`, `region-ref`
- Key functions: `region-alloc`, `region-deref`, `with-region`
- Other contexts: Region operations depend on the shared type model.

## security-labels

- Definition: Normalizes security labels, compares their ranks, and tracks labeled values and allowed information flow.
- Package: `cl-cc/type/security-labels`
- Key types: `labeled-value`
- Key functions: `normalize-security-label`, `labeled-value-flow-allowed-p`, `declassify-labeled-value`
- Other contexts: Security-label validation registers with `advanced-metadata`; subtyping uses its label comparison API.

## units

- Definition: Defines unit dimensions and scales, creates measures, and converts or combines values with compatible units.
- Package: `cl-cc/type/units`
- Key types: `unit-definition`, `measure`
- Key functions: `define-unit`, `convert-measure`, `measure+`
- Other contexts: Unit validation registers with `advanced-metadata`.

## advanced-metadata

- Definition: Defines advanced-type contracts, metadata, core validators, and callback registries for feature-specific validation and normalization.
- Package: `cl-cc/type/advanced-metadata`
- Key types: None.
- Key functions: `validate-type-advanced`
- Other contexts: Domain validators register by stable string ID. Feature-specific validators are owned by their domain features.
