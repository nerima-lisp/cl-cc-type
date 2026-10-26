;;;; cl-cc-type.asd — the type system extracted from the cl-cc compiler.
;;;;
;;;; Files live in the :cl-cc/type package (kind, multiplicity, types,
;;;; inference, checker, ...). The system depends on cl-cc-ast for the AST node
;;;; types referenced during constraint collection and type inference
;;;; (solver-collect, inference, inference-forms, inference-effects). That is
;;;; the only org-internal dependency: cl-cc-type sits at L3/depth 1 in
;;;; DEPENDENCY_POLICY.md.
;;;;
;;;; Both systems live in this one file; there is no separate
;;;; cl-cc-type-test.asd. System names are written as STRINGS rather than
;;;; #:symbols or :keywords, so that reading this file does not depend on the
;;;; reader's current package state.

(in-package #:asdf-user)

(defsystem "cl-cc-type"
  :description "cl-cc type system — kinds, multiplicity, HM inference, type classes, effects"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  ;; Single source of truth for the version: flake.nix reads this form, and
  ;; release.yml refuses to publish a tag that disagrees with it.
  :version "0.2.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-type"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-type/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-type.git")
  :depends-on ("cl-cc-ast")
  :pathname "src"
  :serial t
  :components
  ((:module "syntax" :serial t
    :components ((:file "package")
                 (:file "protocol")))
   (:module "type-model" :serial t
    :components ((:file "package")
                 (:file "condition-macros")
                 (:file "kind")
                 (:file "types-core")
                 (:file "types-extended-advanced-node")
                 (:file "types-extended-nodes")
                 (:file "types-env")
                 (:file "inference-conditions")
                 (:file "printer")
                 (:file "printer-unparse")))
   (:module "registries" :serial t
    :components ((:file "package")
                 (:file "registry")
                 (:file "types-extended-registries")
                 (:file "initialize")))
   (:module "advanced-metadata" :serial t
    :components ((:file "package")
                 (:file "types-extended-advanced-meta")
                 (:file "types-extended-advanced-contract")
                 (:file "types-extended-advanced-meta-validators")
                 (:file "types-extended-advanced-validators")
                 (:file "types-extended-advanced-data")
                 (:file "types-extended-advanced-evidence-data")
                 (:file "types-extended-advanced-validate")
                 (:file "types-extended-advanced-init")))
   (:module "capabilities" :serial t
    :components ((:file "package")
                 (:file "types-extended-capabilities")))
   (:module "concurrency" :serial t
    :components ((:file "package")
                 (:file "types-extended-concurrency")))
   (:module "generics" :serial t
    :components ((:file "package")
                 (:file "generics")))
   (:module "regions" :serial t
    :components ((:file "package")
                 (:file "types-extended-regions")))
   (:module "security-labels" :serial t
    :components ((:file "package")
                 (:file "types-extended-security-labels")))
   (:module "units" :serial t
    :components ((:file "package")
                 (:file "types-extended-units")))
   (:module "quantities" :serial t
    :components ((:file "package")
                 (:file "multiplicity")
                 (:file "types-extended-qtt")))
   (:module "type-level" :serial t
    :components ((:file "package")
                 (:file "types-level-naturals")
                 (:file "types-level-strings")))
   (:module "hlist" :serial t
    :components ((:file "package")
                 (:file "types-hlist")))
   (:module "rows" :serial t
    :components ((:file "package")
                 (:file "row")))
   (:module "effects" :serial t
    :components ((:file "package")
                 (:file "effect")))
   (:module "routing" :serial t
    :components ((:file "package")
                 (:file "types-extended-routing-types")
                 (:file "routing")))
   (:module "dependent" :serial t
    :components ((:file "package")
                 (:file "types-extended-dependent")))
   (:module "ffi" :serial t
    :components ((:file "package")
                 (:file "types-extended-ffi")))
   (:module "channels" :serial t
    :components ((:file "package")
                 (:file "channels")))
   (:module "actors" :serial t
    :components ((:file "package")
                 (:file "actors")))
   (:module "coroutines" :serial t
    :components ((:file "package")
                 (:file "coroutines")))
   (:module "stm" :serial t
    :components ((:file "package")
                 (:file "stm")))
   (:module "simd" :serial t
    :components ((:file "package")
                 (:file "simd")))
   (:module "subtyping" :serial t
    :components ((:file "package")
                 (:file "subtyping")))
   (:module "utility-types" :serial t
    :components ((:file "package")
                 (:file "types-utility")))
   (:module "type-lowering" :serial t
    :components ((:file "package")
                 (:file "parser-guards")
                 (:file "parser")
                 (:file "parser-extended")
                 (:file "parser-typed")))
   (:module "unification" :serial t
    :components ((:file "package")
                 (:file "substitution")
                 (:file "substitution-schemes")
                 (:file "unification")
                 (:file "constraint")
                 (:file "solver")))
   (:module "type-classes" :serial t
    :components ((:file "package")
                 (:file "typeclass")))
   (:module "inference" :serial t
    :components ((:file "package")
                 (:file "solver-collect")
                 (:file "inference")
                 (:file "inference-handlers")
                 (:file "inference-forms")
                 (:file "inference-forms-advanced")
                 (:file "inference-forms-advanced-validators")
                 (:file "inference-forms-advanced-init")
                 (:file "inference-effects")
                 (:file "inference-formatting")))
   (:module "checking" :serial t
    :components ((:file "package")
                 (:file "bidirectional")
                 (:file "checker")))
   (:module "exhaustiveness" :serial t
    :components ((:file "package")
                 (:file "exhaustiveness")))
   ;; Validator registrations are provided by domain features above.
   (:file "advanced-metadata/initialize")
   (:file "package"))
  :in-order-to ((test-op (test-op "cl-cc-type/test"))))

;;; The test system is "cl-cc-type/test" with :pathname "t". It is NOT
;;; cl-cc-type-test (which used to live in its own .asd) and NOT
;;; cl-cc-type/tests.
;;;
;;; cl-cc-ast is listed explicitly even though cl-cc-type already pulls it in:
;;; t/package.lisp does (:use :cl-cc/ast), so the tests depend on it directly
;;; and should say so rather than lean on a transitive edge.
;;;
;;; cl-cc-parse is a test-only dependency: inference-tests.lisp and its four
;;; siblings build their input ASTs with cl-cc/parse:lower-sexp-to-ast. It is
;;; not a dependency of the "cl-cc-type" system above -- the type checker
;;; itself never parses source text, only AST nodes it is handed.
(defsystem "cl-cc-type/test"
  :description "Test system for cl-cc-type, running under cl-weave."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.2.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-type"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-type/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-type.git")
  :depends-on ("cl-cc-type" "cl-cc-ast" "cl-cc-parse" "cl-weave")
  :pathname "t"
  :serial t
  :components
  (
   (:module "support" :serial t
    :components (
     (:file "package")
     (:file "assertions")
     (:file "internal-symbols")
    ))
   (:module "facade" :serial t
    :components (
     (:file "package")
     (:file "facade-test")
    ))
   (:module "actors" :serial t
    :components (
     (:file "package")
     (:static-file "actors-test.lisp")
     (:file "feature-suite")
    ))
   (:module "advanced-metadata" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-node-test.lisp")
     (:static-file "contract-test.lisp")
     (:static-file "init-test.lisp")
     (:static-file "meta-test.lisp")
     (:static-file "meta-validators-test.lisp")
     (:static-file "validate-test.lisp")
     (:file "feature-suite")
    ))
   (:module "capabilities" :serial t
    :components (
     (:file "package")
     (:static-file "capabilities-test.lisp")
     (:file "feature-suite")
    ))
   (:module "channels" :serial t
    :components (
     (:file "package")
     (:static-file "channels-test.lisp")
     (:file "feature-suite")
    ))
   (:module "checking" :serial t
    :components (
     (:file "package")
     (:static-file "bidirectional-test.lisp")
     (:static-file "checker-test.lisp")
     (:file "feature-suite")
    ))
   (:module "concurrency" :serial t
    :components (
     (:file "package")
     (:static-file "concurrency-test.lisp")
     (:file "feature-suite")
    ))
   (:module "coroutines" :serial t
    :components (
     (:file "package")
     (:static-file "coroutines-test.lisp")
     (:file "feature-suite")
    ))
   (:module "dependent" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-dependent-test.lisp")
     (:static-file "dependent-test.lisp")
     (:file "feature-suite")
    ))
   (:module "effects" :serial t
    :components (
     (:file "package")
     (:static-file "effect-test.lisp")
     (:static-file "effects-additional-test.lisp")
     (:static-file "phase-integration-test.lisp")
     (:file "feature-suite")
    ))
   (:module "exhaustiveness" :serial t
    :components (
     (:file "package")
     (:static-file "exhaustiveness-test.lisp")
     (:file "feature-suite")
    ))
   (:module "ffi" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-ffi-test.lisp")
     (:static-file "ffi-test.lisp")
     (:file "feature-suite")
    ))
   (:module "generics" :serial t
    :components (
     (:file "package")
     (:static-file "generics-test.lisp")
     (:file "feature-suite")
    ))
   (:module "hlist" :serial t
    :components (
     (:file "package")
     (:static-file "hlist-test.lisp")
     (:file "feature-suite")
    ))
   (:module "inference" :serial t
    :components (
     (:file "package")
     (:static-file "formatter-edge-cases-test.lisp")
     (:static-file "inference-effect-tests.lisp")
     (:static-file "inference-forms-advanced-test.lisp")
     (:static-file "inference-forms-tests.lisp")
     (:static-file "inference-tests.lisp")
     (:static-file "phase-integration-test.lisp")
     (:static-file "solver-collect-test.lisp")
     (:static-file "type-inference-tests.lisp")
     (:static-file "type-system-inference-test.lisp")
     (:file "feature-suite")
    ))
   (:module "quantities" :serial t
    :components (
     (:file "package")
     (:static-file "multiplicity-test.lisp")
     (:static-file "qtt-test.lisp")
     (:static-file "quantities-additional-test.lisp")
     (:file "feature-suite")
    ))
   (:module "regions" :serial t
    :components (
     (:file "package")
     (:static-file "regions-test.lisp")
     (:file "feature-suite")
    ))
   (:module "registries" :serial t
    :components (
     (:file "package")
     (:static-file "types-extended-registries-test.lisp")
     (:file "feature-suite")
    ))
   (:module "routing" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-route-invalid-test.lisp")
     (:static-file "advanced-route-predicate-test.lisp")
     (:static-file "advanced-route-valid-test.lisp")
     (:static-file "routing-test.lisp")
     (:static-file "types-extended-routing-types-test.lisp")
     (:file "feature-suite")
    ))
   (:module "rows" :serial t
    :components (
     (:file "package")
     (:static-file "row-test.lisp")
     (:static-file "rows-printer-test.lisp")
     (:file "feature-suite")
    ))
   (:module "security-labels" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-security-labels-test.lisp")
     (:static-file "security-labels-test.lisp")
     (:file "feature-suite")
    ))
   (:module "simd" :serial t
    :components (
     (:file "package")
     (:static-file "simd-test.lisp")
     (:file "feature-suite")
    ))
   (:module "stm" :serial t
    :components (
     (:file "package")
     (:static-file "stm-test.lisp")
     (:file "feature-suite")
    ))
   (:module "subtyping" :serial t
    :components (
     (:file "package")
     (:static-file "subtyping-extended-test.lisp")
     (:static-file "subtyping-test.lisp")
     (:file "feature-suite")
    ))
   (:module "syntax" :serial t
    :components (
     (:file "package")
     (:static-file "dispatch-test.lisp")
     (:file "feature-suite")
    ))
   (:module "type-classes" :serial t
    :components (
     (:file "package")
     (:static-file "typeclass-test.lisp")
     (:file "feature-suite")
    ))
   (:module "type-level" :serial t
    :components (
     (:file "package")
     (:static-file "types-level-test.lisp")
     (:file "feature-suite")
    ))
   (:module "type-lowering" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-node-test.lisp")
     (:static-file "core-node-parser-test.lisp")
     (:static-file "extended-node-parser-test.lisp")
     (:static-file "parser-arrow-quantifier-test.lisp")
     (:static-file "parser-test.lisp")
     (:static-file "parser-typed-test.lisp")
     (:static-file "printer-parser-test.lisp")
     (:static-file "property-test.lisp")
     (:static-file "registry-adapter-test.lisp")
     (:static-file "type-phase-parser-test.lisp")
     (:file "feature-suite")
    ))
   (:module "type-model" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-node-test.lisp")
     (:static-file "kind-test.lisp")
     (:static-file "printer-test.lisp")
     (:static-file "type-phase-skolem-test.lisp")
     (:static-file "type-system-effect-test.lisp")
     (:static-file "type-system-test.lisp")
     (:static-file "types-core-nodes-test.lisp")
     (:static-file "types-extended-nodes-children-test.lisp")
     (:static-file "types-extended-nodes-coverage-test.lisp")
     (:static-file "types-extended-nodes-test.lisp")
     (:file "feature-suite")
    ))
   (:module "unification" :serial t
    :components (
     (:file "package")
     (:static-file "constraint-test.lisp")
     (:static-file "solver-test.lisp")
     (:static-file "substitution-test.lisp")
     (:static-file "substitution-zonk-test.lisp")
     (:static-file "unification-advanced-nodes-test.lisp")
     (:static-file "unification-effect-rows-test.lisp")
     (:static-file "unification-test.lisp")
     (:file "feature-suite")
    ))
   (:module "units" :serial t
    :components (
     (:file "package")
     (:static-file "advanced-units-test.lisp")
     (:static-file "units-test.lisp")
     (:file "feature-suite")
    ))
   (:module "utility-types" :serial t
    :components (
     (:file "package")
     (:static-file "utility-types-test.lisp")
     (:file "feature-suite")
    ))
   (:file "package")
  )
  :perform (test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-weave
                                       :run-all
                                       :reporter :spec
                                       :pass-with-no-tests nil)
               (error "cl-cc-type tests failed"))))
