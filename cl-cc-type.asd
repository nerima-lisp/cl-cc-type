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
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-type"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-type/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-type.git")
  :depends-on ("cl-cc-ast")
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "registry")
   (:file "kind")
   (:file "multiplicity")
   (:file "types-core")
   (:file "types-extended-concurrency")
   (:file "types-extended-security-labels")
   (:file "types-extended-regions")
   (:file "types-extended-capabilities")
   (:file "types-extended-units")
   (:file "types-extended-routing-types")
   (:file "types-extended-ffi")
   (:file "types-extended-registries")
   (:file "types-extended-qtt")
   (:file "types-extended-dependent")
   (:file "types-extended-advanced-meta")
   (:file "types-extended-advanced-node")
   (:file "types-extended-advanced-contract")
   (:file "types-extended-advanced-meta-validators")
   (:file "types-extended-advanced-validators")
   (:file "types-extended-advanced-data")
   (:file "types-extended-advanced-evidence-data")
   (:file "types-extended-advanced-validate")
   (:file "types-extended-advanced-init")
   (:file "types-extended-nodes")
   (:file "types-env")
   (:file "substitution")
   (:file "substitution-schemes")
   (:file "unification")
   (:file "subtyping")
   (:file "effect")
   (:file "row")
   (:file "constraint")
   (:file "parser")
   (:file "parser-extended")
   (:file "parser-typed")
   (:file "typeclass")
   (:file "solver")
   (:file "solver-collect")
   (:file "inference")
   (:file "inference-handlers")
   (:file "inference-forms")
   (:file "inference-forms-advanced")
   (:file "inference-forms-advanced-validators")
   (:file "inference-forms-advanced-init")
   (:file "inference-conditions")
   (:file "inference-effects")
   (:file "bidirectional")
   (:file "checker")
   (:file "printer")
   (:file "printer-unparse")
   (:file "exhaustiveness")
   ;; FR-1602/1701/1702/1803/1804/2202-2206/3303-3305 utility modules.
   ;; Keep this order: channels before actors/stm/coroutines/simd.
   (:file "generics")
   (:file "channels")
   (:file "actors")
   (:file "stm")
   (:file "coroutines")
   (:file "simd")
   (:file "routing")
   ;; utils.lisp (FR-1701/1702/1803/1804/3303/3304) split by type family;
   ;; types-utility depends on %field-name= from types-level-strings, so it
   ;; must load after it. No other file in this system depends on load order
   ;; among these five.
   (:file "types-level-naturals")
   (:file "types-level-strings")
   (:file "types-hlist")
   (:file "utils")
   (:file "types-utility"))
  :in-order-to ((test-op (test-op "cl-cc-type/test"))))

;;; The test system is "cl-cc-type/test" with :pathname "t". It is NOT
;;; cl-cc-type-test (which used to live in its own .asd) and NOT
;;; cl-cc-type/tests.
;;;
;;; cl-cc-ast is listed explicitly even though cl-cc-type already pulls it in:
;;; t/package.lisp does (:use :cl-cc/ast), so the tests depend on it directly
;;; and should say so rather than lean on a transitive edge.
(defsystem "cl-cc-type/test"
  :description "Test system for cl-cc-type, running under cl-weave."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-type"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-type/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-type.git")
  :depends-on ("cl-cc-type" "cl-cc-ast" "cl-weave")
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "type-tests")
   (:file "type-effect-tests")
   ;; inference-tests, inference-forms-tests, inference-effect-tests,
   ;; type-inference-tests and type-phase-tests are absent, not disabled: they
   ;; build their input ASTs with lower-sexp-to-ast, which is defined in the
   ;; cl-cc monorepo's parse package (packages/parse/src/cl/lower.lisp) and has
   ;; no standalone repository yet. They come back here, or into an integration
   ;; suite, once cl-cc-parse is extracted. See docs/src/development.md.
   (:file "type-2026-nodes-tests")
   ;; type-2026-advanced-registry-tests is likewise absent: it is a monorepo
   ;; governance meta-test that cross-checks docs/type-advanced.md against the
   ;; homegrown framework's cl-cc/test::*known-test-names* registry. Neither
   ;; exists outside the monorepo, and it asserts nothing about type-system
   ;; behaviour, so it did not follow the code here.
   (:file "type-2026-advanced-semantic-tests")
   (:file "kind-tests")
   (:file "multiplicity-tests")
   (:file "row-tests")
   (:file "subtyping-tests")
   (:file "subtyping-extended-tests")
   (:file "effect-tests")
   (:file "constraint-tests")
   (:file "solver-tests")
   (:file "solver-collect-tests")
   (:file "representation-tests")
   (:file "substitution-tests")
   (:file "unification-tests")
   (:file "type-children-tests")
   (:file "types-extended-coverage-tests")
   (:file "checker-tests")
   (:file "typeclass-tests")
   (:file "printer-tests")
   (:file "parser-tests")
   (:file "parser-arrow-quantifier-tests")
   (:file "parser-typed-tests")
   (:file "exhaustiveness-tests"))
  :perform (test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-weave
                                       :run-all
                                       :reporter :spec
                                       :pass-with-no-tests nil)
               (error "cl-cc-type tests failed"))))
