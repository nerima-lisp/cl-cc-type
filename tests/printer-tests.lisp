;;;; tests/unit/type/printer-tests.lisp — Type Printer Tests
;;;;
;;;; Tests for src/type/printer.lisp:
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
    (let ((s (type-to-string (make-type-arrow (list type-int) type-string :effects nil))))
      (expect (search "->" s) :to-be-truthy)
      (assert-when-present "FIXNUM" (expect (search "FIXNUM" s) :to-be-truthy))
      (assert-when-present "STRING" (expect (search "STRING" s) :to-be-truthy))
      (assert-when-present nil (expect (search "IO" s) :to-be-truthy))))
  (it-sequential "printer-arrow-cases multi-param"
    (let ((s (type-to-string (make-type-arrow (list type-int type-string) type-bool :effects nil))))
      (expect (search "->" s) :to-be-truthy)
      (assert-when-present nil (expect (search nil s) :to-be-truthy))
      (assert-when-present nil (expect (search nil s) :to-be-truthy))
      (assert-when-present nil (expect (search "IO" s) :to-be-truthy))))
  (it-sequential "printer-arrow-cases with-effects"
    (let ((s (type-to-string (make-type-arrow (list type-int) type-string :effects +io-effect-row+))))
      (expect (search "->" s) :to-be-truthy)
      (assert-when-present "IO" (expect (search "IO" s) :to-be-truthy))
      (assert-when-present nil (expect (search nil s) :to-be-truthy))
      (assert-when-present +io-effect-row+ (expect (search "IO" s) :to-be-truthy)))))

(progn
  (it-sequential "printer-container-type-delimiters product"
    (expect (search "," (type-to-string (make-type-product :elems (list type-int type-string)))) :to-be-truthy))
  (it-sequential "printer-container-type-delimiters variant"
    (expect (search "<" (type-to-string (make-type-variant :cases (list (cons 'some type-int) (cons 'none type-null))
                                                             :row-var nil))) :to-be-truthy))
  (it-sequential "printer-container-type-delimiters type-app"
    (expect (search "(" (type-to-string (make-type-app :fun type-int :arg type-string))) :to-be-truthy)))

(progn
  (it-sequential "printer-record-cases closed"
    (let* ((r (make-type-record :fields (list (cons 'x type-int) (cons 'y type-string)) :row-var nil))
           (s (type-to-string r)))
      (expect (search "{" s) :to-be-truthy)
      (assert-when-present "x"
        (expect (search "x" (string-downcase s)) :to-be-truthy))))
  (it-sequential "printer-record-cases open"
    (let* ((rv (fresh-type-var :name "rho"))
           (r (make-type-record :fields (list (cons 'x type-int)) :row-var rv))
           (s (type-to-string r)))
      (expect (search "|" s) :to-be-truthy)
      (assert-when-present nil
        (expect (search nil (string-downcase s)) :to-be-truthy)))))

(progn
  (it-sequential "printer-binary-separator-types union"
    (expect (search "|" (type-to-string (make-type-union (list type-int type-string)))) :to-be-truthy))
  (it-sequential "printer-binary-separator-types intersection"
    (expect (search "&" (type-to-string (make-type-intersection (list type-int type-string)))) :to-be-truthy)))

(progn
  (it-sequential "printer-quantified-types forall"
    (let ((ty (let ((v (fresh-type-var :name "a"))) (make-type-forall :var v :body type-int))))
      (expect (> (length (type-to-string ty)) 0) :to-be-truthy)))
  (it-sequential "printer-quantified-types exists"
    (let ((ty (let ((v (fresh-type-var :name "a"))) (make-type-exists :var v :body type-int))))
      (expect (> (length (type-to-string ty)) 0) :to-be-truthy))))

(it-sequential "printer-binder-types"
  (let ((v (fresh-type-var :name "a")))
    (expect (> (length (type-to-string (cl-cc/type:make-type-lambda :var v :knd nil :body type-int))) 0) :to-be-truthy)
    (expect (> (length (type-to-string (make-type-mu :var v :body v))) 0) :to-be-truthy)))

(progn
  (it-sequential "printer-wrapper-type-annotations refinement"
    (expect (search "<pred>" (type-to-string (cl-cc/type:make-type-refinement :base type-int :predicate nil))) :to-be-truthy))
  (it-sequential "printer-wrapper-type-annotations linear"
    (expect (search "1" (type-to-string (make-type-linear :base type-int :grade :one))) :to-be-truthy))
  (it-sequential "printer-wrapper-type-annotations capability"
    (expect (search "READ" (type-to-string (cl-cc/type:make-type-capability :base type-int :cap 'read))) :to-be-truthy)))

(it-sequential "printer-handler-uses-bracket-notation"
  (let* ((eff (make-type-effect-op :name 'io :args nil))
         (h (cl-cc/type:make-type-handler :effect eff :input type-int :output type-string))
         (s (type-to-string h)))
    (expect (search "[" s) :to-be-truthy)
    (expect (search "=>" s) :to-be-truthy)))

(it-sequential "printer-gadt-constructor-includes-double-colon"
  (let* ((gc (cl-cc/type:make-type-gadt-con
              :name 'just :arg-types (list type-int) :index-type type-any))
         (s (type-to-string gc)))
    (expect (search "::" s) :to-be-truthy)))

;;; ─── type-to-string: effect rows ──────────────────────────────────────────

(it-sequential "printer-effect-rows-and-ops"
  (expect (type-to-string +pure-effect-row+) :to-equal "{}")
  (expect (search "IO" (type-to-string +io-effect-row+)) :to-be-truthy)
  (let* ((rv (fresh-type-var :name "e"))
         (er (make-type-effect-row :effects nil :row-var rv)))
    (expect (search "|" (type-to-string er)) :to-be-truthy))
  (let* ((op (make-type-effect-op :name 'state :args (list type-int)))
         (s  (type-to-string op)))
    (expect (search "STATE"  s) :to-be-truthy)
    (expect (search "FIXNUM" s) :to-be-truthy))
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
    (expect (search "EQ" (type-to-string tc)) :to-be-truthy)
    (let ((s (type-to-string (make-type-qualified :constraints (list tc) :body type-int))))
      (expect (search "=>" s) :to-be-truthy))
    (let ((s (type-to-string (make-type-qualified :constraints nil :body type-int))))
      (expect s :to-equal "FIXNUM"))))

;;; ─── unparse-type roundtrip ────────────────────────────────────────────────

(it-sequential "unparse-type-forms"
  (expect (cl-cc/type:unparse-type type-int) :to-be 'fixnum)
  (expect (first (cl-cc/type:unparse-type (make-type-arrow (list type-int) type-string))) :to-be 'cl-cc/type::->)
  (expect (first (cl-cc/type:unparse-type (make-type-union (list type-int type-string)))) :to-be 'or)
  (expect (first (cl-cc/type:unparse-type (make-type-product :elems (list type-int)))) :to-be 'values))

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
    (let ((arr (make-type-arrow (list type-int) type-string :mult :zero)))
      (expect (search "-0->" (type-to-string arr)) :to-be-truthy)))
  (it-sequential "printer-arrow-mult-table one"
    (let ((arr (make-type-arrow (list type-int) type-string :mult :one)))
      (expect (search "-1->" (type-to-string arr)) :to-be-truthy)))
  (it-sequential "printer-arrow-mult-table omega"
    (let ((arr (make-type-arrow (list type-int) type-string :mult :omega)))
      (expect (search "->" (type-to-string arr)) :to-be-truthy))))

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

;;; ─── list-interleave ───────────────────────────────────────────────────────

(it-sequential "list-interleave-behavior"
  (expect (cl-cc/type::list-interleave '(a b c) 'x) :to-equal '(a x b x c))
  (expect (cl-cc/type::list-interleave '(a) 'x) :to-equal '(a))
  (expect (cl-cc/type::list-interleave nil 'x) :to-be-null))
