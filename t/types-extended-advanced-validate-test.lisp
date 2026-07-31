;;;; t/types-extended-advanced-validate-test.lisp — Implementation-Evidence Completeness Tests
;;;;
;;;; Tests for src/types-extended-advanced-validate.lisp:
;;;; type-advanced-semantics-implemented-p and the module/API/test-anchor
;;;; evidence-availability helpers it composes.

(in-package :cl-cc-type/test)

(it-sequential "type-advanced-semantics-implemented-p-reflects-current-evidence-availability"
  ;; FR-1501's module/API/test-anchor evidence resolves correctly against this
  ;; standalone checkout (src/... paths under the :cl-cc-type system), so it
  ;; reports implemented. An unknown feature id is never implemented.
  (expect (cl-cc/type:type-advanced-semantics-implemented-p "FR-1501") :to-be-truthy)
  (expect (cl-cc/type:type-advanced-semantics-implemented-p "FR-9999-NOT-A-FEATURE") :to-be-null)
  (expect (cl-cc/type::%type-advanced-implementation-api-available-p 'cl-cc/type:make-hlist-type)
          :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-implementation-api-available-p
           'cl-cc/type::totally-unbound-fn-xyz)
          :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-api-available-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-module-present-p "src/types-hlist.lisp")
          :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-implementation-module-present-p
           "packages/type/src/types-extended-nodes.lisp")
          :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-module-present-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-test-anchor-available-p 42) :to-be-falsy))

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
          (expect (cl-cc/type::%type-advanced-implementation-test-anchor-available-p
                   :advanced-validate-exact-anchor)
                  :to-be-truthy)
          ;; No exact hash entry exists for this anchor, but a registered
          ;; test's ".../ANCHOR-NAME [case]" name contains
          ;; "/ANCHOR-NAME [" as a substring, so the fallback SEARCH loop
          ;; matches it.
          (expect (cl-cc/type::%type-advanced-implementation-test-anchor-available-p
                   :advanced-validate-prefix-anchor)
                  :to-be-truthy)
          ;; Neither an exact hash entry nor any case-prefix match exists.
          (expect (cl-cc/type::%type-advanced-implementation-test-anchor-available-p
                   :advanced-validate-unregistered-anchor)
                  :to-be-falsy))
      (makunbound registry-var)
      (unintern registry-var test-pkg)
      (unintern exact-anchor-symbol test-pkg)
      (unintern prefix-carrier-symbol test-pkg))))

(it-sequential "type-advanced-implementation-evidence-complete-p-checks-every-required-shape"
  ;; No evidence record at all.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p nil) :to-be-falsy)
  ;; Modules must be a non-empty list.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules nil
            :api-symbols '(cl-cc/type:make-hlist-type) :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; API symbols must be a non-empty list.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/types-hlist.lisp")
            :api-symbols nil :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; Test anchors must be a non-empty list.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/types-hlist.lisp")
            :api-symbols '(cl-cc/type:make-hlist-type) :test-anchors nil))
          :to-be-falsy)
  ;; A module path that does not exist fails the module-presence EVERY check.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/does-not-exist-anywhere.lisp")
            :api-symbols '(cl-cc/type:make-hlist-type) :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; An unbound API symbol fails the api-available EVERY check.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/types-hlist.lisp")
            :api-symbols '(cl-cc/type::totally-unbound-fn-xyz) :test-anchors '(some-anchor)))
          :to-be-falsy)
  ;; A non-symbol test anchor fails the test-anchor-available EVERY check.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/types-hlist.lisp")
            :api-symbols '(cl-cc/type:make-hlist-type) :test-anchors '(42)))
          :to-be-falsy)
  ;; A fully well-formed evidence record (a real module path, a real bound
  ;; API symbol, and a real symbol test anchor) is complete.
  (expect (cl-cc/type::%type-advanced-implementation-evidence-complete-p
           (cl-cc/type::%make-type-advanced-implementation-evidence
            :feature-id "FR-TEST" :modules '("src/types-hlist.lisp")
            :api-symbols '(cl-cc/type:make-hlist-type)
            :test-anchors '(advanced-null-safety-option-parses-nullable-union)))
          :to-be-truthy))

(it-sequential "type-advanced-validate-contract-directly-exercises-arg-count-property-and-evidence-clauses"
  (let ((node (cl-cc/type:make-type-advanced :feature-id "FR-1501"
                                              :args (list cl-cc/type:type-int))))
    ;; When both exact-args and min-args are set, only exact-args is
    ;; enforced: the node's single arg satisfies exact-args 1 even though it
    ;; would violate a min-args of 5, and validation passes, returning the
    ;; node unchanged.
    (expect (cl-cc/type::%type-advanced-validate-contract
             node
             (cl-cc/type::make-type-advanced-contract
              :id "FR-1501" :semantic-domain :safety :exact-args 1 :min-args 5))
            :to-be node)
    ;; An exact-args mismatch signals.
    (signals error
        (cl-cc/type::%type-advanced-validate-contract
         node
         (cl-cc/type::make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :exact-args 2)))
    ;; min-args is enforced only when exact-args is absent.
    (signals error
        (cl-cc/type::%type-advanced-validate-contract
         node
         (cl-cc/type::make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :min-args 5)))
    ;; A required property absent from the node signals.
    (signals error
        (cl-cc/type::%type-advanced-validate-contract
         node
         (cl-cc/type::make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :required-properties '(:missing))))
    ;; A property-predicate keyed on a property the node does not have is
    ;; never consulted, so validation still passes.
    (expect (cl-cc/type::%type-advanced-validate-contract
             node
             (cl-cc/type::make-type-advanced-contract
              :id "FR-1501" :semantic-domain :safety
              :property-predicates '((:absent-property . consp))))
            :to-be node)
    ;; requires-evidence-p with no evidence on the node signals.
    (signals error
        (cl-cc/type::%type-advanced-validate-contract
         node
         (cl-cc/type::make-type-advanced-contract
          :id "FR-1501" :semantic-domain :safety :requires-evidence-p t)))
    (let ((evidenced (cl-cc/type:make-type-advanced :feature-id "FR-1501"
                                                     :args (list cl-cc/type:type-int)
                                                     :evidence 42)))
      ;; requires-evidence-p is satisfied once evidence is present.
      (expect (cl-cc/type::%type-advanced-validate-contract
               evidenced
               (cl-cc/type::make-type-advanced-contract
                :id "FR-1501" :semantic-domain :safety :requires-evidence-p t))
              :to-be evidenced)
      ;; An evidence-predicate that accepts the evidence value passes.
      (expect (cl-cc/type::%type-advanced-validate-contract
               evidenced
               (cl-cc/type::make-type-advanced-contract
                :id "FR-1501" :semantic-domain :safety :evidence-predicate 'integerp))
              :to-be evidenced)
      ;; An evidence-predicate that rejects the evidence value signals.
      (signals error
          (cl-cc/type::%type-advanced-validate-contract
           evidenced
           (cl-cc/type::make-type-advanced-contract
            :id "FR-1501" :semantic-domain :safety :evidence-predicate 'stringp)))
      ;; With no evidence on the node at all, an evidence-predicate is never
      ;; consulted, so it does not by itself force evidence to be present.
      (expect (cl-cc/type::%type-advanced-validate-contract
               node
               (cl-cc/type::make-type-advanced-contract
                :id "FR-1501" :semantic-domain :safety :evidence-predicate 'stringp))
              :to-be node))))

(it-sequential "validate-type-advanced-rejects-non-nodes-and-unregistered-feature-ids-directly"
  ;; A non-type-advanced value is rejected before any registry lookup runs.
  (signals error (cl-cc/type:validate-type-advanced 42))
  ;; A well-formed struct whose feature id was never registered is rejected
  ;; by validate-type-advanced's own registry check, distinct from (and
  ;; reached before) %type-advanced-validate-by-feature's missing-contract
  ;; check exercised below.
  (let ((node (cl-cc/type::%make-type-advanced :feature-id "FR-9999-NEVER-REGISTERED"
                                                :name 'advanced :args nil
                                                :properties nil :evidence nil)))
    (signals error (cl-cc/type:validate-type-advanced node))
    ;; type-advanced-valid-p wraps both failure modes in a handler-case and
    ;; reports them as a plain NIL rather than propagating the error.
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-falsy))
  (expect (cl-cc/type:type-advanced-valid-p 42) :to-be-falsy))

(it-sequential "type-advanced-validate-by-feature-signals-when-no-explicit-contract-is-registered"
  ;; %type-advanced-validate-by-feature only consults the contract registry
  ;; (unlike validate-type-advanced, it never checks the feature registry),
  ;; so calling it directly on a feature id with no registered contract
  ;; reaches its own "no semantic contract is implemented" branch, even
  ;; though every id reachable through the public API always has one thanks
  ;; to %ensure-type-advanced-contract-coverage.
  (let ((node (cl-cc/type::%make-type-advanced :feature-id "FR-9999-NO-CONTRACT-REGISTERED"
                                                :name 'advanced :args nil
                                                :properties nil :evidence nil)))
    (signals error (cl-cc/type::%type-advanced-validate-by-feature node))))

