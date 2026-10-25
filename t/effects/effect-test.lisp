;;;; t/effect-test.lisp — Algebraic Effect System Tests
;;;;
;;;; Tests for src/effect.lisp:
;;;; effect-def, effect registry, effect-row-union, effect-row-subset-p.

(in-package #:cl-cc/type/effects/test)

;;; ─── Helpers ─────────────────────────────────────────────────────────────────

(defun make-effect-op (name)
  "Shorthand for a simple effect-op with no args."
  (make-type-effect-op :name name :args nil))

(defun make-effect-row (&rest names)
  "Build a closed effect row from effect name symbols."
  (make-type-effect-row
   :effects (mapcar #'make-effect-op names)
   :row-var nil))

(defun make-open-effect-row (var &rest names)
  "Build an open effect row with a row variable."
  (make-type-effect-row
   :effects (mapcar #'make-effect-op names)
   :row-var var))

;;; ─── effect-def struct ──────────────────────────────────────────────────────

(it-sequential "effect-def-creation"
  (let ((ed (make-effect-def
             :name 'io
             :type-params nil
             :operations '((read-line . nil) (write-line . nil)))))
    (expect (effect-def-name ed) :to-be 'io)
    (expect (length (effect-def-operations ed)) :to-equal 2)))

;;; ─── effect registry ────────────────────────────────────────────────────────

(it-sequential "effect-registry-operations"
  (progv (list '*effect-registry*) (list (make-hash-table :test #'eq)) (let ((ed (make-effect-def :name 'test-eff :type-params nil :operations nil)))
      (register-effect 'test-eff ed)
      (expect (lookup-effect 'test-eff) :to-be ed))
    (expect (lookup-effect 'nonexistent) :to-be-null)))

;;; ─── %effect-node-name ──────────────────────────────────────────────────────
;;; Every EFFECTS list built across this file's tests contains only genuine
;;; TYPE-EFFECT-OP nodes, so %EFFECT-NODE-NAME's error arm was untested.

(it-sequential "effect-node-name-signals-for-a-non-effect-op"
  (signals error
      (funcall (internal-function "cl-cc/type/effects" "%EFFECT-NODE-NAME") "not-an-effect-op")))

;;; ─── effect-row-union ───────────────────────────────────────────────────────

(it-sequential "effect-row-union-behavior"
  (expect (length (type-effect-row-effects
                    (effect-row-union (make-effect-row :io) (make-effect-row :state))))
          :to-equal 2)
  (expect (length (type-effect-row-effects
                    (effect-row-union (make-effect-row :io :state)
                                                  (make-effect-row :io :exn))))
          :to-equal 3)
  (expect (type-effect-row-effects
           (effect-row-union (make-effect-row) (make-effect-row))) :to-be-null)
  (let* ((rv (fresh-type-var))
         (result (effect-row-union (make-effect-row :io)
                                               (make-open-effect-row rv :state))))
    (expect (type-var-p (type-effect-row-row-var result)) :to-be-truthy)))

;;; ─── effect-row-subset-p ────────────────────────────────────────────────────

(it-sequential "effect-row-subset-p-behavior"
  (with-soft-assertions
    (expect (effect-row-subset-p (make-effect-row) (make-effect-row :io :state))
            :to-be-truthy)
    (let ((r (make-effect-row :io :state)))
      (expect (effect-row-subset-p r r) :to-be-truthy))
    (expect (effect-row-subset-p (make-effect-row :io) (make-effect-row :io :state))
            :to-be-truthy)
    (expect (effect-row-subset-p (make-effect-row :io :state) (make-effect-row :io))
            :to-be-falsy)
    (expect (effect-row-subset-p (make-effect-row :io :state :exn)
                                             (make-open-effect-row (fresh-type-var)))
            :to-be-truthy)))

(it-sequential "effect-row-extend"
  (let* ((op  (make-type-effect-op :name 'state :args nil))
         (row (effect-row-extend op +pure-effect-row+)))
    (expect (type-effect-row-p row) :to-be-truthy)
    (expect (length (type-effect-row-effects row)) :to-equal 1)
    (expect (type-effect-op-name
             (first (type-effect-row-effects row))) :to-be 'state))
  (let* ((rv   (fresh-type-var "e"))
         (base (make-type-effect-row :effects nil :row-var rv))
         (op   (make-type-effect-op :name 'io :args nil))
         (ext  (effect-row-extend op base)))
    (expect (type-var-p (type-effect-row-row-var ext)) :to-be-truthy)))

(it-sequential "effect-row-restrict"
  (let* ((op1 (make-type-effect-op :name 'io :args nil))
         (op2 (make-type-effect-op :name 'state :args nil))
         (row (make-type-effect-row :effects (list op1 op2) :row-var nil))
         (restricted (effect-row-restrict 'io row)))
    (expect (length (type-effect-row-effects restricted)) :to-equal 1)
    (expect (type-effect-op-name
             (first (type-effect-row-effects restricted))) :to-be 'state))
  (let* ((op  (make-type-effect-op :name 'io :args nil))
         (row (make-type-effect-row :effects (list op) :row-var nil))
         (restricted (effect-row-restrict 'state row)))
    (expect (length (type-effect-row-effects restricted)) :to-equal 1)))

(it-sequential "effect-row-member-p"
  (let* ((op  (make-type-effect-op :name 'io :args nil))
         (row (make-type-effect-row :effects (list op) :row-var nil)))
    (expect (effect-row-member-p 'io row) :to-be-truthy)
    (expect (effect-row-member-p 'state row) :to-be-falsy)
    (expect (effect-row-member-p 'io +pure-effect-row+) :to-be-falsy)))

(it-sequential "effect-registry"
  (progv (list '*effect-registry*) (list (make-hash-table :test #'eq)) (let ((edef (make-effect-def :name 'state :type-params nil :operations nil)))
      (register-effect 'state edef)
      (let ((found (lookup-effect 'state)))
        (expect (effect-def-p found) :to-be-truthy)
        (expect (effect-def-name found) :to-be 'state)))
    (expect (lookup-effect 'nonexistent) :to-be-null)))

(it-sequential "effect-row-union"
  (let* ((op-io    (make-type-effect-op :name 'io :args nil))
         (op-state (make-type-effect-op :name 'state :args nil))
         (op-io2   (make-type-effect-op :name 'io :args nil))
         (row1 (make-type-effect-row :effects (list op-io) :row-var nil))
         (row2 (make-type-effect-row :effects (list op-io2 op-state) :row-var nil))
         (merged (effect-row-union row1 row2)))
    (expect (length (type-effect-row-effects merged)) :to-equal 2))
  (let* ((rv (fresh-type-var "e"))
         (row1 (make-type-effect-row :effects nil :row-var nil))
         (row2 (make-type-effect-row :effects nil :row-var rv))
         (merged (effect-row-union row1 row2)))
    (expect (type-var-p (type-effect-row-row-var merged)) :to-be-truthy)))

(it-sequential "effect-row-subset-p"
  (let* ((op  (make-type-effect-op :name 'io :args nil))
         (row (make-type-effect-row :effects (list op) :row-var nil)))
    (expect (effect-row-subset-p +pure-effect-row+ row) :to-be-truthy))
  (let* ((rv   (fresh-type-var "e"))
         (op   (make-type-effect-op :name 'io :args nil))
         (row1 (make-type-effect-row :effects (list op) :row-var nil))
         (row2 (make-type-effect-row :effects nil :row-var rv)))
    (expect (effect-row-subset-p row1 row2) :to-be-truthy))
  (let* ((op-io    (make-type-effect-op :name 'io :args nil))
         (op-state (make-type-effect-op :name 'state :args nil))
         (big   (make-type-effect-row :effects (list op-io op-state) :row-var nil))
         (small (make-type-effect-row :effects (list op-io) :row-var nil)))
    (expect (effect-row-subset-p big small) :to-be-falsy)))

(it-sequential
  "effect-row-extend-adds-op"
  (let* ((op (make-type-effect-op :name :io :args nil))
         (row (make-type-effect-row :effects nil :row-var nil))
         (row2 (effect-row-extend op row)))
    (expect (length (type-effect-row-effects row2)) :to-equal 1)))

(it-sequential
  "effect-row-restrict-removes"
  (let* ((op1 (make-type-effect-op :name :io :args nil))
         (op2 (make-type-effect-op :name :state :args nil))
         (row (make-type-effect-row :effects (list op1 op2) :row-var nil))
         (row2 (effect-row-restrict :io row)))
    (expect (length (type-effect-row-effects row2)) :to-equal 1)))

(it-sequential
  "effect-row-member-p-behavior"
  (let ((row-with-io
        (make-type-effect-row
          :effects
          (list (make-type-effect-op :name :io :args nil))
          :row-var
          nil))
        (empty-row (make-type-effect-row :effects nil :row-var nil)))
    (expect (effect-row-member-p :io row-with-io) :to-be-truthy)
    (expect (effect-row-member-p :io empty-row) :to-be-falsy)))

(it-sequential
  "effect-row-member-p-is-falsy-for-a-non-effect-row-argument"
  (expect (effect-row-member-p :io type-int) :to-be-falsy))
