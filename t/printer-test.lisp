;;;; t/printer-test.lisp — Type Printer Tests
;;;;
;;;; Tests for src/printer.lisp:
;;;; type-to-string for all type-node subtypes, unparse-type,
;;;; list-interleave, looks-like-type-specifier-p.
;;;; Coverage goal: every defmethod clause + every data table entry.

(in-package :cl-cc-type/test)

;;; ─── type-to-string: basic types ───────────────────────────────────────────

(progn
  (it-sequential "printer-primitive-types int"
    (expect (type-to-string type-int) :to-equal "FIXNUM"))
  (it-sequential "printer-primitive-types string"
    (expect (type-to-string type-string) :to-equal "STRING")))

(progn
  (it-sequential "printer-var-contains-substring named"
    (expect (search "alpha" (type-to-string (fresh-type-var :name "alpha"))) :to-be-truthy))
  (it-sequential "printer-var-contains-substring rigid"
    (expect (search "sk" (type-to-string (fresh-rigid-var "test"))) :to-be-truthy)))

(it-sequential "printer-linked-type-var-shows-resolved-type"
  (let ((v (fresh-type-var :name "a")))
    (setf (cl-cc/type:type-var-link v) type-int)
    (expect (type-to-string v) :to-equal "FIXNUM")))

(it-sequential "printer-type-scheme-produces-non-empty-string"
  (let* ((v (fresh-type-var :name "a"))
         (scheme (make-type-scheme (list v) v))
         (s (type-to-string scheme)))
    (expect (> (length s) 0) :to-be-truthy)))

;;; ─── type-to-string: composite types ───────────────────────────────────────

(progn
  (it-sequential "printer-arrow-cases single-param"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :effects nil))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\""))
  (it-sequential "printer-arrow-cases multi-param"
    (expect (type-to-string (make-type-arrow (list type-int type-string) type-bool :effects nil))
            :to-match-inline-snapshot "\"(FIXNUM -> STRING) -> BOOLEAN\""))
  (it-sequential "printer-arrow-cases with-effects"
    (expect (type-to-string
             (make-type-arrow (list type-int) type-string :effects +io-effect-row+))
            :to-match-inline-snapshot "\"FIXNUM -[{IO}]-> STRING\""))
  (it-sequential "printer-arrow-cases effects-eq-to-the-pure-singleton"
    ;; TYPE-TO-STRING's (AND EFFECTS (NOT (EQ EFFECTS +PURE-EFFECT-ROW+))
    ;; (TYPE-EFFECT-ROW-EFFECTS EFFECTS)) only ever saw EFFECTS=NIL (the
    ;; first conjunct false, short-circuiting immediately) or a genuine
    ;; I/O row (all three conjuncts true); using +PURE-EFFECT-ROW+ itself
    ;; is non-NIL but EQ to the singleton, isolating the second conjunct.
    (expect (type-to-string
             (make-type-arrow (list type-int) type-string :effects +pure-effect-row+))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\""))
  (it-sequential "printer-arrow-cases effects-non-pure-object-with-no-concrete-effects"
    ;; A distinct (not EQ +PURE-EFFECT-ROW+) row with an open row-var but
    ;; no concrete effects isolates the third conjunct's own false branch.
    (expect (type-to-string
             (make-type-arrow (list type-int) type-string
                              :effects (make-type-effect-row :effects nil
                                                             :row-var (fresh-type-var))))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\"")))

(progn
  (it-sequential "printer-container-type-delimiters product"
    (expect (type-to-string (make-type-product :elems (list type-int type-string)))
            :to-match-inline-snapshot "\"(FIXNUM, STRING)\""))
  (it-sequential "printer-container-type-delimiters variant"
    (expect (type-to-string
             (make-type-variant
              :cases (list (cons 'some type-int) (cons 'none type-null))
              :row-var nil))
            :to-match-inline-snapshot "\"<SOME: FIXNUM, NONE: NULL>\""))
  (it-sequential "printer-container-type-delimiters type-app"
    (expect (type-to-string (make-type-app :fun type-int :arg type-string))
            :to-match-inline-snapshot "\"(FIXNUM STRING)\"")))

(progn
  (it-sequential "printer-record-cases closed"
    (expect (type-to-string
             (make-type-record :fields (list (cons 'x type-int) (cons 'y type-string))
                                :row-var nil))
            :to-match-inline-snapshot "\"{X: FIXNUM, Y: STRING}\""))
  (it-sequential "printer-record-cases open"
    (let* ((rv (fresh-type-var :name "rho"))
           (r (make-type-record :fields (list (cons 'x type-int)) :row-var rv))
           (s (type-to-string r)))
      (expect (search "|" s) :to-be-truthy)
      (expect (search "{X: FIXNUM |" s) :to-be-truthy))))

(progn
  (it-sequential "printer-binary-separator-types union"
    (expect (type-to-string (make-type-union (list type-int type-string)))
            :to-match-inline-snapshot "\"(FIXNUM | STRING)\""))
  (it-sequential "printer-binary-separator-types intersection"
    (expect (type-to-string (make-type-intersection (list type-int type-string)))
            :to-match-inline-snapshot "\"(FIXNUM & STRING)\"")))

(progn
  (it-sequential "printer-quantified-types forall"
    (let ((ty (let ((v (fresh-type-var :name "a"))) (make-type-forall :var v :body type-int))))
      (expect (> (length (type-to-string ty)) 0) :to-be-truthy)))
  (it-sequential "printer-quantified-types exists"
    (let ((ty (let ((v (fresh-type-var :name "a"))) (make-type-exists :var v :body type-int))))
      (expect (> (length (type-to-string ty)) 0) :to-be-truthy))))

(it-sequential "printer-binder-types"
  (let ((v (fresh-type-var :name "a")))
    (expect (> (length (type-to-string
                         (cl-cc/type:make-type-lambda :var v :knd nil :body type-int)))
                0)
            :to-be-truthy)
    (expect (> (length (type-to-string (make-type-mu :var v :body v))) 0) :to-be-truthy)))

(progn
  (it-sequential "printer-wrapper-type-annotations refinement"
    (expect (search "<pred>"
                     (type-to-string
                      (cl-cc/type:make-type-refinement :base type-int :predicate nil)))
            :to-be-truthy))
  (it-sequential "printer-wrapper-type-annotations linear"
    (expect (search "1" (type-to-string (make-type-linear :base type-int :grade :one)))
            :to-be-truthy))
  (it-sequential "printer-wrapper-type-annotations capability"
    (expect (search "READ"
                     (type-to-string
                      (cl-cc/type:make-type-capability :base type-int :cap 'read)))
            :to-be-truthy)))

(it-sequential "printer-handler-uses-bracket-notation"
  (let ((eff (make-type-effect-op :name 'io :args nil)))
    (expect (type-to-string
             (cl-cc/type:make-type-handler :effect eff :input type-int :output type-string))
            :to-match-inline-snapshot "\"[IO => FIXNUM / STRING]\"")))

(it-sequential "printer-gadt-constructor-includes-double-colon"
  (expect (type-to-string
           (cl-cc/type:make-type-gadt-con
            :name 'just :arg-types (list type-int) :index-type type-any))
          :to-match-inline-snapshot "\"JUST :: FIXNUM -> T\""))

;;; ─── type-to-string: effect rows ──────────────────────────────────────────

(it-sequential "printer-effect-rows-and-ops"
  (expect (type-to-string +pure-effect-row+) :to-equal "{}")
  (expect (type-to-string +io-effect-row+) :to-match-inline-snapshot "\"{IO}\"")
  (let* ((rv (fresh-type-var :name "e"))
         (er (make-type-effect-row :effects nil :row-var rv)))
    (expect (search "|" (type-to-string er)) :to-be-truthy))
  (expect (type-to-string (make-type-effect-op :name 'state :args (list type-int)))
          :to-match-inline-snapshot "\"(STATE FIXNUM)\"")
  (let* ((rv  (fresh-type-var :name 'epsilon))
         (row (make-type-effect-row
               :effects (list (make-type-effect-op :name 'io))
               :row-var rv))
         (s (type-to-string row)))
    (expect (search "IO" (string-upcase s)) :to-be-truthy)
    (expect (search "|" s) :to-be-truthy)))

;;; ─── type-to-string: constraint / qualified ───────────────────────────────

(it-sequential "printer-constraint-and-qualified"
  (let ((tc (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int)))
    (expect (type-to-string tc) :to-match-inline-snapshot "\"(EQ FIXNUM)\"")
    (expect (type-to-string (make-type-qualified :constraints (list tc) :body type-int))
            :to-match-inline-snapshot "\"((EQ FIXNUM)) => FIXNUM\"")
    (let ((s (type-to-string (make-type-qualified :constraints nil :body type-int))))
      (expect s :to-equal "FIXNUM"))))

;;; ─── unparse-type roundtrip ────────────────────────────────────────────────

(it-sequential "unparse-type-forms"
  (expect (cl-cc/type:unparse-type type-int) :to-be 'fixnum)
  (expect (first (cl-cc/type:unparse-type (make-type-arrow (list type-int) type-string)))
          :to-be 'cl-cc/type::->)
  (expect (first (cl-cc/type:unparse-type (make-type-union (list type-int type-string))))
          :to-be 'or)
  (expect (first (cl-cc/type:unparse-type (make-type-product :elems (list type-int))))
          :to-be 'values))

;;; ─── unparse-type: remaining type-node kinds ──────────────────────────────
;;; (merged from t/types-extended-advanced-semantics-test.lisp)

(it-sequential "unparse-type-covers-vars-app-forall-intersection-advanced-and-default"
  (expect (cl-cc/type:unparse-type (cl-cc/type:fresh-type-var :name 'x)) :to-be 'x)
  (expect (symbolp (cl-cc/type:unparse-type (cl-cc/type:fresh-type-var))) :to-be-truthy)
  (let ((a (cl-cc/type:fresh-type-var :name 'a)))
    (expect (string= (symbol-name
                       (first (cl-cc/type:unparse-type
                               (cl-cc/type:make-type-forall :var a :body cl-cc/type:type-int))))
                      "FORALL")
            :to-be-truthy))
  (expect (first (cl-cc/type:unparse-type
                  (cl-cc/type:make-type-intersection
                   (list cl-cc/type:type-int cl-cc/type:type-string))))
          :to-be 'and)
  (expect (first (cl-cc/type:unparse-type
                  (cl-cc/type:make-type-constructor 'list (list cl-cc/type:type-int))))
          :to-be 'list)
  (let ((anon-app (cl-cc/type:make-type-app :fun (cl-cc/type:fresh-type-var)
                                             :arg cl-cc/type:type-int)))
    (expect (listp (cl-cc/type:unparse-type anon-app)) :to-be-truthy)
    (expect (= (length (cl-cc/type:unparse-type anon-app)) 2) :to-be-truthy))
  (expect (cl-cc/type:unparse-type :not-a-type-node) :to-be :not-a-type-node)
  ;; type-advanced: registered surface head vs. the generic 'advanced' head.
  (let* ((route-node (cl-cc/type:parse-type-specifier '(api-type (get "/users/{id}" integer user))))
         (route-spec (cl-cc/type:unparse-type route-node)))
    (expect (string= (symbol-name (first route-spec)) "API-TYPE") :to-be-truthy))
  (let* ((generic-node (cl-cc/type:parse-type-specifier
                        '(advanced fr-1606 cache-entry
                          :dependency-graph call-graph :cache module-cache :lsp t)))
         (generic-spec (cl-cc/type:unparse-type generic-node)))
    (expect (string= (symbol-name (first generic-spec)) "ADVANCED") :to-be-truthy)
    (expect (string= (symbol-name (second generic-spec)) "FR-1606") :to-be-truthy)
    (expect (cl-cc/type:type-advanced-valid-p (cl-cc/type:parse-type-specifier generic-spec))
            :to-be-truthy))
  ;; Neither pre-existing advanced-node example above sets :EVIDENCE, so
  ;; %UNPARSE-TYPE-ADVANCED's (WHEN (TYPE-ADVANCED-EVIDENCE ty) ...) arm
  ;; was never taken.
  (let* ((proof-node (cl-cc/type:parse-type-specifier
                       '(advanced fr-2001 my-lemma :evidence (proof my-lemma-witness))))
         (proof-spec (cl-cc/type:unparse-type proof-node)))
    (expect (member :evidence proof-spec) :to-be-truthy))
  ;; %UNPARSE-TYPE-ADVANCED interns the feature-id symbol in SURFACE-HEAD's
  ;; own package when it has one, falling back to *PACKAGE* otherwise; an
  ;; uninterned surface head (impossible to produce via PARSE-TYPE-SPECIFIER,
  ;; whose reader always interns) is built directly to reach that fallback.
  (let ((uninterned-head-node
          (cl-cc/type:make-type-advanced :feature-id "FR-1601" :name (make-symbol "CUSTOM-HEAD")
                                         :args (list 'payload) :properties nil)))
    (expect (cl-cc/type:unparse-type uninterned-head-node) :to-be-truthy)))

;;; ─── type-to-string: edge cases not covered above ────────────────────────

(progn
  (it-sequential "printer-atomic-sentinel-strings nil-val"
    (expect (type-to-string nil) :to-equal "NIL"))
  (it-sequential "printer-atomic-sentinel-strings unknown"
    (expect (type-to-string cl-cc/type:+type-unknown+) :to-equal "?")))

(progn
  (it-sequential "printer-unnamed-var-format type-var"
    (let ((s (type-to-string (fresh-type-var :name nil))))
      (expect (search "?t" s) :to-be-truthy)))
  (it-sequential "printer-unnamed-var-format rigid-var"
    (let ((s (type-to-string (fresh-rigid-var nil))))
      (expect (search "sk" s) :to-be-truthy)
      (expect (search "[" s) :to-be-falsy))))

(it-sequential "printer-fallback-hash-table"
  (expect (search "#<type" (type-to-string (make-hash-table))) :to-be-truthy))

(progn
  (it-sequential "printer-looks-like-type-specifier-p fixnum"
    (expect (cl-cc/type:looks-like-type-specifier-p 'fixnum) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p string"
    (expect (cl-cc/type:looks-like-type-specifier-p 'string) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p int-shorthand"
    (expect (cl-cc/type:looks-like-type-specifier-p 'cl-cc/type::int) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p bool-shorthand"
    (expect (cl-cc/type:looks-like-type-specifier-p 'cl-cc/type::bool) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p or-composite"
    (expect (cl-cc/type:looks-like-type-specifier-p '(or fixnum string)) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p and-composite"
    (expect (cl-cc/type:looks-like-type-specifier-p '(and fixnum string)) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p bang-prefix"
    (expect (cl-cc/type:looks-like-type-specifier-p '(!linear fixnum)) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p frobnitz-sym"
    (expect (cl-cc/type:looks-like-type-specifier-p 'frobnitz) :to-be-falsy))
  (it-sequential "printer-looks-like-type-specifier-p frobnitz-list"
    (expect (cl-cc/type:looks-like-type-specifier-p '(frobnitz fixnum)) :to-be-falsy)))

(progn
  (it-sequential "printer-arrow-mult-table zero"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :mult :zero))
            :to-match-inline-snapshot "\"FIXNUM -0-> STRING\""))
  (it-sequential "printer-arrow-mult-table one"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :mult :one))
            :to-match-inline-snapshot "\"FIXNUM -1-> STRING\""))
  (it-sequential "printer-arrow-mult-table omega"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :mult :omega))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\""))
  (it-sequential "printer-arrow-mult-table signals-for-an-unknown-multiplicity"
    ;; TYPE-ARROW's MULT slot carries no :TYPE restriction (unlike, e.g.,
    ;; TYPE-ADVANCED's NAME), so %ARROW-STRING's own OR/ERROR fallback --
    ;; untested by the three known-good keywords above -- is genuinely
    ;; reachable via a hand-built arrow.
    (signals error
        (type-to-string (make-type-arrow (list type-int) type-string :mult :bogus)))))

(it-sequential "printer-type-error-sentinel"
  (let ((e1 (make-type-error :message "unbound x"))
        (e2 (make-type-error :message "unknown")))
    (expect (type-to-string e1) :to-match-inline-snapshot "\"<error: unbound x>\"")
    (expect (type-to-string e2) :to-equal "?")
    (expect (type-to-string cl-cc/type:+type-unknown+) :to-equal "?")))

(it-sequential "printer-compound-types"
  (with-soft-assertions
    (let ((pair (make-type-product :elems (list type-int type-string))))
      (expect (type-to-string pair) :to-match-inline-snapshot "\"(FIXNUM, STRING)\""))
    (let ((closed (make-type-record :fields (list (cons 'x type-int)
                                                  (cons 'y type-bool))
                                    :row-var nil)))
      (let ((s (type-to-string closed)))
        (expect (search "X" (string-upcase s)) :to-be-truthy)
        (expect (search "Y" (string-upcase s)) :to-be-truthy)))
    (let ((open (make-type-record :fields (list (cons 'x type-int))
                                  :row-var (fresh-type-var :name 'rho))))
      (expect (search "|" (type-to-string open)) :to-be-truthy))
    (let ((lin (make-type-linear :base type-int :grade :one)))
      (let ((s (type-to-string lin)))
        (expect (search "1" s) :to-be-truthy)
        (expect (search "FIXNUM" s) :to-be-truthy)))))

(progn
  (it-sequential "printer-unicode-type-operators forall"
    (let* ((a  (fresh-type-var :name 'a))
           (fn (make-type-arrow (list a) a))
           (ty (make-type-forall :var a :body fn)))
      (expect (search "∀" (type-to-string ty)) :to-be-truthy)))
  (it-sequential "printer-unicode-type-operators mu"
    (let* ((a (fresh-type-var :name 'a))
           (ty (make-type-mu :var a :body (make-type-union (list type-null a)))))
      (expect (search "μ" (type-to-string ty)) :to-be-truthy))))

;;; ─── type-to-string: type-advanced direct printer coverage ───────────────
;;; Exercises the property-loop and :EVIDENCE branches of the type-advanced
;;; method, and %advanced-display-value on nested conses, type-nodes, and
;;; plain atoms (keywords/numbers are prin1-print-package-independent, so
;;; they hand-compute deterministically unlike bare symbols).

(it-sequential "printer-type-advanced-generic-head-full"
  (let ((adv (cl-cc/type:make-type-advanced
              :feature-id "FR-1802"
              :args (list 42 (list 1 2) cl-cc/type:type-int)
              :properties (list (cons :level 3) (cons :mode :fast))
              :evidence :confirmed)))
    (expect (type-to-string adv)
            :to-match-inline-snapshot
            "\"(ADVANCED FR-1802 42 (1 2) FIXNUM LEVEL 3 MODE :FAST :EVIDENCE :CONFIRMED)\"")))

(it-sequential "printer-type-advanced-registered-surface-head"
  (expect (type-to-string (cl-cc/type:make-type-dynamic cl-cc/type:type-string))
          :to-match-inline-snapshot "\"(DYNAMIC STRING)\""))

;;; NOTE: TYPE-TO-STRING's (SYMBOLP SURFACE-HEAD) conjunct (printer.lisp)
;;; looks untested but is not: TYPE-ADVANCED's NAME slot is declared
;;; `:type symbol` (types-extended-advanced-node.lisp), so SBCL itself
;;; guarantees the check can never observe a non-symbol -- confirmed by
;;; SBCL rejecting a `(%make-type-advanced ... :name "not-a-symbol" ...)`
;;; attempt here at compile time with "conflicts with its asserted type
;;; SYMBOL". Left undone, like the other struct-enforced guards documented
;;; elsewhere in this file's CHANGELOG history.

;;; ─── type-to-string: type-scheme quantified-vars branch ──────────────────

(it-sequential "printer-type-scheme-null-vars"
  (expect (type-to-string (make-type-scheme nil type-int))
          :to-match-inline-snapshot "\"FIXNUM\""))

(it-sequential "printer-type-scheme-non-null-vars-exact"
  (let* ((v (fresh-type-var :name "a"))
         (scheme (make-type-scheme (list v) v)))
    (expect (type-to-string scheme) :to-match-inline-snapshot "\"(∀?a. ?a)\"")))

;;; ─── type-to-string: %format-row-fields empty-fields edge cases ──────────

(it-sequential "printer-row-fields-empty-record-closed"
  (expect (type-to-string (make-type-record :fields nil :row-var nil))
          :to-match-inline-snapshot "\"{}\""))

(it-sequential "printer-row-fields-empty-record-open"
  (let ((rv (fresh-type-var :name "rho")))
    (expect (type-to-string (make-type-record :fields nil :row-var rv))
            :to-match-inline-snapshot "\"{ | ?rho}\"")))

(it-sequential "printer-row-fields-empty-variant-closed"
  (expect (type-to-string (make-type-variant :cases nil :row-var nil))
          :to-match-inline-snapshot "\"<>\""))

;;; ─── list-interleave ───────────────────────────────────────────────────────

(it-sequential "list-interleave-behavior"
  (expect (cl-cc/type::list-interleave '(a b c) 'x) :to-equal '(a x b x c))
  (expect (cl-cc/type::list-interleave '(a) 'x) :to-equal '(a))
  (expect (cl-cc/type::list-interleave nil 'x) :to-be-null))
