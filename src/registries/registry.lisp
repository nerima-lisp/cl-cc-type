;;;; registry.lisp — early-loading, dependency-free macro infrastructure
;;;;
;;;; Loaded immediately after package.lisp (before any of the call sites
;;;; that use these macros) so they are available at macro-expansion time
;;;; everywhere in :cl-cc/type. Logically each of these belongs with the
;;;; other general utilities in utils.lisp, but utils.lisp loads last in
;;;; cl-cc-type.asd (after every file that needs them), so the macros
;;;; themselves live in this small, dependency-free file instead.

(in-package :cl-cc/type/registries)

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
  (let* ((package  (or (symbol-package name) *package*))
         (upcase   (string-upcase (string name)))
         (var      (or var-name (intern (format nil "*~A-REGISTRY*" upcase) package)))
         (reg      (intern (format nil "REGISTER-~A" upcase) package))
         (look     (intern (format nil "LOOKUP-~A" upcase) package))
         (key-form (if key-fn `(funcall ,key-fn key) 'key)))
    `(progn
       (defvar ,var (make-hash-table :test ,test) ,documentation)
       (defun ,reg (key value)
         (setf (gethash ,key-form ,var) value))
       (defun ,look (key)
         (gethash ,key-form ,var ,@(when default-supplied-p (list default)))))))

(define-registry type-alias :test #'eq :documentation "Maps type alias names to their type specifications.")
