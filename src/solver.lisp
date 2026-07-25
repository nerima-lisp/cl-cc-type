;;;; solver.lisp - OutsideIn(X) Constraint Solver
;;;;
;;;; Implements the constraint solver used by inference.lisp.
;;;;
;;;; Public API:
;;;;   solve-constraints  (constraints subst)
;;;;       -> (values new-subst residual-constraints)
;;;;   collect-constraints (ast env)
;;;;       -> (values type constraints)

(in-package :cl-cc/type)

;;; ─── per-kind constraint solvers ──────────────────────────────────────────
;;; Each helper solves one constraint kind against CURRENT-SUBST and returns
;;; (values new-subst residual), where RESIDUAL is either the (possibly
;;; substituted) constraint C when it could not be discharged, or NIL when it
;;; was solved/dismissed. solve-constraints below dispatches to these.

(defun %solve-equal-constraint (c current-subst)
  "Solve a (:equal t1 t2) constraint via unification."
  (let ((args (constraint-args c)))
    (multiple-value-bind (new-subst ok)
        (type-unify (first args) (second args) current-subst)
      (if ok
          (values new-subst nil)
          ;; Unification failed: leave as residual (error recovery)
          (values current-subst c)))))

(defun %solve-subtype-constraint (c current-subst)
  "Solve a (:subtype t1 t2) constraint via a subtyping check."
  (let* ((args (constraint-args c))
         (t1  (zonk (first args)  current-subst))
         (t2  (zonk (second args) current-subst)))
    (if (is-subtype-p t1 t2)
        (values current-subst nil)
        ;; Record as residual (don't blow up, let caller decide)
        (values current-subst c))))

(defun %solve-typeclass-constraint (c current-subst)
  "Solve a (:typeclass C tau) instance-check constraint."
  (let* ((args       (constraint-args c))
         (class-name (first args))
         (tau        (zonk (second args) current-subst)))
    (cond
      ;; Free variable: defer (becomes residual until zonked)
      ((type-var-p tau)
       (if (and (default-numeric-typeclass-p class-name)
                *default-numeric-type*)
           (multiple-value-bind (new-subst ok)
               (type-unify tau *default-numeric-type* current-subst)
             (if ok
                 (values new-subst nil)
                 (values current-subst c)))
           (values current-subst c)))
      ;; Unknown participates in gradual typing, so do not retain a
      ;; residual typeclass obligation for it. Other type errors stay
      ;; residual so callers can surface the failure explicitly.
      ((type-unknown-p tau)
       (values current-subst nil))
      ((type-error-p tau)
       (values current-subst c))
      ;; Check instance
      ((has-typeclass-instance-p class-name tau)
       (values current-subst nil))
      ;; No instance found: residual (caller may report error)
      (t
       (values current-subst c)))))

(defun %solve-implication-constraint (c current-subst)
  "Solve a (:implication vars given wanted) GADT / rank-N constraint.
Simplified: locally solve given+wanted with fresh vars."
  (let* ((args   (constraint-args c))
         (qvars  (first args))
         (given  (second args))
         (wanted (third args)))
    ;; Extend subst with fresh vars for qvars (local scope)
    (let ((local-subst (make-substitution)))
      (dolist (v qvars)
        (subst-extend! v
                        (fresh-type-var :name (type-var-name v)
                                        :upper-bound (type-var-upper-bound v)
                                        :lower-bound (type-var-lower-bound v))
                        local-subst))
      ;; Solve given locally
      (multiple-value-bind (s2 _r)
          (solve-constraints (mapcar (lambda (g)
                                       (constraint-substitute g local-subst))
                                     given)
                             local-subst)
        (declare (ignore _r))
        ;; Solve wanted under given's solution
        (multiple-value-bind (_s3 r2)
            (solve-constraints (mapcar (lambda (w)
                                         (constraint-substitute w s2))
                                       wanted)
                               s2)
          (declare (ignore _s3))
          ;; Residual wanted propagate as implication residuals
          (if r2
              (values current-subst c)
              (values current-subst nil)))))))

(defun %solve-effect-subset-constraint (c current-subst)
  "Solve an (:effect-subset e1 e2) effect row inclusion constraint."
  (let* ((args (constraint-args c))
         (e1   (zonk (first args)  current-subst))
         (e2   (zonk (second args) current-subst)))
    (if (and (type-effect-row-p e1) (type-effect-row-p e2))
        (if (effect-row-subset-p e1 e2)
            (values current-subst nil)
            (values current-subst c))
        (values current-subst nil))))

(defun %solve-mult-leq-constraint (c current-subst)
  "Solve a (:mult-leq q1 q2) multiplicity ordering constraint."
  (let* ((args (constraint-args c))
         (q1   (first args))
         (q2   (second args)))
    (if (mult-leq q1 q2)
        (values current-subst nil)
        (values current-subst c))))

(defun %solve-row-lacks-constraint (c current-subst)
  "Solve a (:row-lacks rho label) row-does-not-contain-label constraint.
Only discharges the constraint when the row is concrete and the label is
definitely absent. Open row variables are accepted here; concrete open rows
stay residual so the caller can refine them later."
  (let* ((args  (constraint-args c))
         (rho   (zonk (first args) current-subst))
         (label (second args)))
    (cond
      ((type-var-p rho)
       (values current-subst nil))
      ((or (type-record-p rho)
           (type-variant-p rho)
           (type-effect-row-p rho))
       (if (row-closed-p rho)
           (if (or (row-select label rho)
                   (and (type-effect-row-p rho)
                        (effect-row-member-p label rho)))
               (values current-subst c)
               (values current-subst nil))
           (values current-subst nil)))
      (t
       (values current-subst c)))))

(defun %solve-kind-equal-constraint (c current-subst)
  "Solve a (:kind-equal k1 k2) kind equality constraint."
  (let* ((args (constraint-args c))
         (k1   (first args))
         (k2   (second args)))
    (if (kind-equal-p k1 k2)
        (values current-subst nil)
        (values current-subst c))))

;;; ─── solve-constraints ────────────────────────────────────────────────────
;;; Thin worklist dispatcher. Each arm delegates to a %solve-<kind>-constraint
;;; helper above; all per-kind logic lives there.

(defun solve-constraints (constraints subst)
  "OutsideIn(X) constraint solver.
CONSTRAINTS is a list of constraint structs (from constraint.lisp).
SUBST       is a substitution (from substitution.lisp).

Returns (values new-subst residual-constraints).
  new-subst   — the substitution extended by equality solving.
  residual    — constraints that could not be discharged (typeclass, implication)."
  (unless subst (setf subst (make-substitution)))
  (let ((residual nil)
        (current-subst subst))
    (dolist (c constraints)
      ;; Apply current substitution before inspecting
      (let ((c (constraint-substitute c current-subst)))
        (multiple-value-bind (new-subst r)
            (ecase (constraint-kind c)
              (:equal          (%solve-equal-constraint         c current-subst))
              (:subtype        (%solve-subtype-constraint       c current-subst))
              (:typeclass      (%solve-typeclass-constraint     c current-subst))
              (:implication    (%solve-implication-constraint   c current-subst))
              (:effect-subset  (%solve-effect-subset-constraint c current-subst))
              (:mult-leq       (%solve-mult-leq-constraint      c current-subst))
              (:row-lacks      (%solve-row-lacks-constraint     c current-subst))
              (:kind-equal     (%solve-kind-equal-constraint    c current-subst)))
          (setf current-subst new-subst)
          (when r (push r residual)))))

    (values current-subst (nreverse residual))))

;;; collect-constraints (AST walker that generates equality constraints)
;;; is in solver-collect.lisp (loaded next).
