;;;; registry.lisp — early-loading, dependency-free macro infrastructure
;;;;
;;;; Loaded immediately after package.lisp (before any of the call sites
;;;; that use these macros) so they are available at macro-expansion time
;;;; everywhere in :cl-cc/type. Logically each of these belongs with the
;;;; other general utilities in utils.lisp, but utils.lisp loads last in
;;;; cl-cc-type.asd (after every file that needs them), so the macros
;;;; themselves live in this small, dependency-free file instead.

(in-package :cl-cc/type)

;;; ─── Registry-defining macro ──────────────────────────────────────────────
;;; Many files in this system need a simple hash-table-backed registry:
;;; a defvar plus a register-X/lookup-X pair.  DEFINE-REGISTRY generates that
;;; trio so call sites do not hand-write the boilerplate.  It intentionally
;;; only covers the *plain* shape (register takes a key and a value, lookup
;;; takes a key); registries with real logic beyond a gethash setter/getter
;;; (composite multi-arg keys, value construction, validation, normalization)
;;; are left hand-written at their call sites.

(defmacro define-registry (name &key (test ''eql) key-fn (default nil default-supplied-p)
                                      var-name documentation)
  "Define *NAME-REGISTRY*, REGISTER-NAME, and LOOKUP-NAME around a hash-table.

Generates:
  *NAME-REGISTRY*  (or VAR-NAME, when supplied) — the backing hash table,
                   created with :test TEST and DOCUMENTATION as its docstring.
  REGISTER-NAME (key value) — (setf (gethash key registry) value)
  LOOKUP-NAME   (key)       — (gethash key registry)

KEY-FN, when supplied, is a function designator FUNCALLed on KEY before it
indexes the table, in both REGISTER-NAME and LOOKUP-NAME — useful for
package-independent or otherwise normalized keys.

DEFAULT, when supplied, is passed as GETHASH's third argument in LOOKUP-NAME.

VAR-NAME lets the backing hash-table keep an existing name (e.g.
*effect-signature-table*) instead of the derived *NAME-REGISTRY*."
  (let* ((upcase   (string-upcase (string name)))
         (var      (or var-name (intern (format nil "*~A-REGISTRY*" upcase))))
         (reg      (intern (format nil "REGISTER-~A" upcase)))
         (look     (intern (format nil "LOOKUP-~A" upcase)))
         (key-form (if key-fn `(funcall ,key-fn key) 'key)))
    `(progn
       (defvar ,var (make-hash-table :test ,test) ,documentation)
       (defun ,reg (key value)
         (setf (gethash ,key-form ,var) value))
       (defun ,look (key)
         (gethash ,key-form ,var ,@(when default-supplied-p (list default)))))))

;;; ─── Simple-condition-defining macro ──────────────────────────────────────
;;; Several files in this system define a condition with the shape "one
;;; error class, N :initarg/:reader slots that follow the NAME-SLOT naming
;;; convention, and a single-clause :report that FORMATs a fixed template
;;; against the condition's own readers". DEFINE-SIMPLE-CONDITION generates
;;; that shape so call sites do not hand-write the :initarg/:reader/:report
;;; boilerplate. Conditions whose :report needs more than a straight FORMAT
;;; call against CONDITION, or whose slots do not follow the NAME-SLOT
;;; convention, are left hand-written at their call sites.

(defmacro define-simple-condition (name parent slots &optional report-control &rest report-args)
  "Define condition NAME inheriting from PARENT with SLOTS.

Each element of SLOTS is either a slot name or (SLOT-NAME INITFORM); every
slot gets an :initarg matching its keywordized name and a NAME-SLOT-NAME
reader.

When REPORT-CONTROL is non-nil, also attach a (:report ...) clause whose
body is (format stream REPORT-CONTROL ,@REPORT-ARGS), with CONDITION bound
to the signaled condition instance."
  `(define-condition ,name (,parent)
     ,(mapcar (lambda (slot)
                (let ((slot-name (if (consp slot) (first slot) slot)))
                  `(,slot-name
                    :initarg ,(intern (symbol-name slot-name) :keyword)
                    ,@(when (consp slot) `(:initform ,(second slot)))
                    :reader ,(intern (format nil "~A-~A" name slot-name)))))
              slots)
     ,@(when report-control
         `((:report (lambda (condition stream)
                      (declare (ignorable condition))
                      (format stream ,report-control ,@report-args)))))))

;;; ─── Keyword-normalizing function macro ───────────────────────────────────
;;; Several files define a function that normalizes a symbol/string/keyword
;;; designator into a keyword using the exact same four-branch COND.
;;; DEFINE-KEYWORD-NORMALIZER generates that function so call sites do not
;;; hand-write the COND. Normalizers with different fallback semantics (for
;;; example, signaling an error instead of returning the value unchanged, or
;;; upcasing a symbol's name before interning) are genuinely different and
;;; are left hand-written at their call sites.

(defmacro define-keyword-normalizer (name (param) documentation)
  "Define NAME (PARAM), a function that normalizes PARAM into a keyword:
keywords pass through unchanged, symbols intern by name, strings intern
upcased, and anything else is returned as-is."
  `(defun ,name (,param)
     ,documentation
     (cond
       ((keywordp ,param) ,param)
       ((symbolp ,param) (intern (symbol-name ,param) :keyword))
       ((stringp ,param) (intern (string-upcase ,param) :keyword))
       (t ,param))))

;;; ─── Module-boundary fboundp assertion macro ───────────────────────────────
;;; checker.lisp is a module boundary that only re-exports functions defined
;;; in other files, and checks at load time that each one actually got
;;; defined where it expects. ASSERT-FBOUNDP-IN generates one such ASSERT so
;;; the boundary file does not hand-write the same "fboundp, nil, explanatory
;;; message" shape once per re-exported name.

(defmacro assert-fboundp-in (name source-file)
  "Assert that NAME is FBOUNDP, reporting SOURCE-FILE as where it should have
been defined if the assertion fails."
  `(assert (fboundp ',name) nil
           ,(format nil "checker.lisp: ~A must be defined in ~A" name source-file)))

;;; ─── Parser guard-and-report macro ─────────────────────────────────────────
;;; parser.lisp and parser-extended.lisp are full of "signal TYPE-PARSE-ERROR
;;; unless this shape-check holds" guards — over twenty of them, one per
;;; compound-type-syntax arity/shape rule. PARSER-REQUIRE generates that
;;; shape so call sites do not hand-write UNLESS + TYPE-PARSE-ERROR every
;;; time. Guards embedded in a COND clause (the clause condition already is
;;; the check) do not use it — there is no UNLESS to fold away there.

(defmacro parser-require (predicate format-control &rest format-args)
  "Signal TYPE-PARSE-ERROR via FORMAT-CONTROL/FORMAT-ARGS unless PREDICATE
holds."
  `(unless ,predicate
     (type-parse-error ,format-control ,@format-args)))

;;; ─── :detail-condition signaling macros ────────────────────────────────────
;;; types-extended-ffi.lisp and types-extended-routing-types.lisp both define
;;; their validation condition (FFI-VALIDATION-ERROR, ROUTE-VALIDATION-ERROR)
;;; with DEFINE-SIMPLE-CONDITION's :DETAIL slot convention, then repeatedly
;;; hand-write `(error 'CONDITION :detail (format nil "..." args))` — as a
;;; COND fallback clause in some places, guarded by an UNLESS in others.
;;; ERROR-WITH-DETAIL covers the shape itself; REQUIRE-WITH-DETAIL adds the
;;; UNLESS guard for call sites that need one.

(defmacro error-with-detail (condition-type format-control &rest format-args)
  "Signal CONDITION-TYPE with a :DETAIL initarg built from
(format nil FORMAT-CONTROL . FORMAT-ARGS)."
  `(error ',condition-type :detail (format nil ,format-control ,@format-args)))

(defmacro require-with-detail (predicate condition-type format-control &rest format-args)
  "Signal CONDITION-TYPE via ERROR-WITH-DETAIL unless PREDICATE holds."
  `(unless ,predicate
     (error-with-detail ,condition-type ,format-control ,@format-args)))
