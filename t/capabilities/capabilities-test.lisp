;;;; t/types-extended-capabilities-test.lisp — Capability Sets Tests
;;;;
;;;; Tests for src/capabilities/types-extended-capabilities.lisp:
;;;; capability implication, restriction, and effect derivation.

(in-package #:cl-cc/type/capabilities/test)

(it-sequential "capabilities-support-implication-restriction-and-effects"
  (let* ((writer (make-capability '(:file-write :network-read)))
         (read-only (restrict-capability writer :read-only)))
    (expect (capability-allows-p writer :file-read) :to-be-truthy)
    (expect (capability-implies-p writer :file-read) :to-be-truthy)
    (expect (capability-allows-p read-only :file-write) :to-be-falsy)
    (expect (capability-allows-p read-only :file-read) :to-be-truthy)
    (expect (member :READ-FILE (capability-effects read-only) :test #'eq)
            :to-be-truthy)))

;;; ─── make-capability: symbol and string permission designators ─────────

(it-sequential "make-capability-normalizes-symbol-and-string-designators"
  (let ((cap (make-capability (list 'file-write "network-read"))))
    ;; 'file-write is a plain (non-keyword) symbol -> exercises the
    ;; symbolp branch of %normalize-permission.
    ;; "network-read" is a string -> exercises the stringp branch.
    (expect (capability-allows-p cap :file-write) :to-be-truthy)
    (expect (capability-allows-p cap :file-read) :to-be-truthy)
    (expect (capability-allows-p cap :network-read) :to-be-truthy)
    (expect (equal (capability-permissions cap)
                   '(:file-read :file-write :network-read))
            :to-be-truthy)))

;;; ─── %normalize-permission: unsupported designator signals an error ────

(it-sequential "capability-allows-p-and-implies-p-signal-on-unsupported-designator"
  (let ((cap (make-capability '(:file-read))))
    (signals error (capability-allows-p cap 42))
    (signals error (capability-implies-p cap 42))))

;;; ─── permissions without a -READ/-WRITE suffix: no read variant ────────

(it-sequential "capability-treats-dashless-and-short-permissions-as-standalone"
  ;; :execute has no -READ/-WRITE suffix (string= comparison fails), and
  ;; :db is shorter than both suffixes (length short-circuit in %suffixp
  ;; fails before any string= comparison) -- together these exercise every
  ;; branch of %permission-read-variant / %suffixp, plus the nil-read-variant
  ;; branch of %permission-closure and the "no dash" branch of
  ;; capability-effects.
  (let ((cap (make-capability '(:execute :db))))
    (expect (equal (capability-permissions cap) '(:db :execute))
            :to-be-truthy)
    (expect (capability-allows-p cap :execute) :to-be-truthy)
    (expect (capability-allows-p cap :db) :to-be-truthy)
    (expect (equal (capability-effects cap) '(:db :execute))
            :to-be-truthy)))

;;; ─── capability-implies-p: RIGHT is a whole capability set ──────────────

(it-sequential "capability-implies-p-compares-whole-capability-sets"
  (let* ((broad (make-capability '(:file-write :network-write)))
         (file-read-only (make-capability '(:file-read)))
         (file-write-only (make-capability '(:file-write))))
    ;; broad's permissions include :file-read (implied by :file-write) and
    ;; :network-read/-write, so it subsumes the single-permission
    ;; file-read-only capability -> every check succeeds.
    (expect (capability-implies-p broad file-read-only) :to-be-truthy)
    ;; file-read-only only allows :file-read, so it cannot subsume
    ;; file-write-only (which also requires :file-write) -> every check
    ;; fails partway through.
    (expect (capability-implies-p file-read-only file-write-only)
            :to-be-falsy)))

;;; ─── restrict-capability: capability and list restrictions, and errors ──

(it-sequential "restrict-capability-accepts-capability-and-list-restrictions"
  (let* ((base (make-capability '(:file-write :network-write)))
         (allowed-cap (make-capability '(:file-read :file-write)))
         (restricted-by-cap (restrict-capability base allowed-cap))
         (restricted-by-list (restrict-capability
                               base '(:file-read :file-write))))
    (expect (capability-allows-p restricted-by-cap :file-read)
            :to-be-truthy)
    (expect (capability-allows-p restricted-by-cap :file-write)
            :to-be-truthy)
    (expect (capability-allows-p restricted-by-cap :network-write)
            :to-be-falsy)
    (expect (capability-allows-p restricted-by-cap :network-read)
            :to-be-falsy)
    ;; A list restriction is converted to a capability and re-dispatched,
    ;; so it must produce the same result as restricting with that
    ;; capability directly.
    (expect (equal (capability-permissions restricted-by-list)
                   (capability-permissions restricted-by-cap))
            :to-be-truthy)
    (signals error (restrict-capability base 42))))

