;;;; types-extended-concurrency.lisp — Concurrency traits and Send/Sync registry

(in-package :cl-cc/type)

;;; ─── Concrete advanced semantic APIs (merged for Nix flake source) ─────────

(defstruct concurrency-traits
  "Concrete Send/Sync traits for a type designator."
  (type nil)
  (send nil :type boolean)
  (sync nil :type boolean)
  (note nil))

(defvar *concurrency-trait-registry* (make-hash-table :test #'equal)
  "Overrides for Send/Sync trait information keyed by type designator.")

(defparameter +default-concurrency-traits+
  '((integer t t)
    (fixnum t t)
    (float t t)
    (double-float t t)
    (single-float t t)
    (rational t t)
    (character t t)
    (string t t)
    (symbol t t)
    (keyword t t)
    (null t t)
    (boolean t t)
    (pathname nil nil)
    (hash-table nil nil)
    (cons nil nil)
    (vector nil nil)
    (array nil nil)
    (function nil nil))
  "Built-in Send/Sync defaults for common host types.")

(defun %default-concurrency-traits (type)
  "Return the built-in trait entry for TYPE, or NIL when unknown."
  (let ((entry (assoc type +default-concurrency-traits+ :test #'equal)))
    (when entry
      (make-concurrency-traits :type (first entry)
                               :send (second entry)
                               :sync (third entry)
                               :note :default))))

(defun register-concurrency-traits (type &key send sync note)
  "Register concrete Send/Sync information for TYPE."
  (let ((traits (make-concurrency-traits :type type
                                         :send (not (null send))
                                         :sync (not (null sync))
                                         :note note)))
    (setf (gethash type *concurrency-trait-registry*) traits)
    traits))

(defun lookup-concurrency-traits (type)
  "Return registered or built-in traits for TYPE."
  (or (gethash type *concurrency-trait-registry*)
      (%default-concurrency-traits type)))

(defun sendable-type-p (type)
  "Return T when TYPE may be transferred across threads."
  (let ((traits (lookup-concurrency-traits type)))
    (and traits (concurrency-traits-send traits))))

(defun shareable-type-p (type)
  "Return T when TYPE may be shared across threads by reference."
  (let ((traits (lookup-concurrency-traits type)))
    (and traits (concurrency-traits-sync traits))))

(defun validate-send (type)
  "Return T when TYPE is Send."
  (sendable-type-p type))

(defun validate-sync (type)
  "Return T when TYPE is Sync."
  (shareable-type-p type))

(defun validate-spawn-argument (type)
  "Return T when TYPE may cross a spawn boundary."
  (validate-send type))

(defun validate-shared-reference (type)
  "Return T when TYPE may be shared through references."
  (validate-sync type))


