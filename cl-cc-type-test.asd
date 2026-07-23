(asdf:defsystem "cl-cc-type-test"
  :description "Tests for cl-cc-type (cl-weave)."
  :version "0.1.0"
  :author "takeokunn"
  :license "MIT"
  :homepage "https://github.com/nerima-lisp/cl-cc-type"
  :depends-on ("cl-cc-type" "cl-cc-ast" "cl-weave")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "type-tests")
               (:file "type-effect-tests")
               ;; type-inference-tests / type-phase-tests omitted: they build
               ;; ASTs via lower-sexp-to-ast (cl-cc-parse). They move to an
               ;; integration suite once parse is extracted.
               (:file "type-2026-nodes-tests")
               ;; type-2026-advanced-registry-tests omitted: a monorepo
               ;; governance meta-test that reads docs/type-advanced.md and the
               ;; homegrown framework's *known-test-names* registry — neither
               ;; exists standalone. It is not a type-system behaviour test.
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
               ;; inference-tests / inference-forms-tests / inference-effect-tests
               ;; omitted: they build ASTs via lower-sexp-to-ast, which belongs
               ;; to cl-cc-parse. They move to an integration suite once parse is
               ;; extracted; type-inference-tests below stays (no parse dependency).
               (:file "exhaustiveness-tests"))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-weave
                                       :run-all
                                       :reporter :spec
                                       :pass-with-no-tests nil)
               (error "cl-cc-type tests failed"))))
