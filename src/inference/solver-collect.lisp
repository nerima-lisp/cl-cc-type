;;;; solver-collect.lisp — Constraint Collection Pass
;;;
;;; Extracted from solver.lisp.
;;; Contains: collect-constraints — AST walker that generates equality
;;;   constraints for the OutsideIn(X) solver.
;;;
;;; Depends on solver.lisp / constraint.lisp (make-equal-constraint),
;;;   substitution-schemes.lisp (instantiate, generalize, fresh-type-var),
;;;   representation.lisp (make-type-arrow, type-int, type-string, etc.),
;;;   environment.lisp (type-env-lookup, type-env-extend, type-env-extend*,
;;;     type-to-scheme).
;;; Load order: immediately after solver.lisp.
;;;
;;; Each AST node kind collect-constraints handles gets its own %collect-<kind>
;;; helper below, matching the per-form-function convention inference-forms.lisp
;;; already uses for infer-if/infer-let/infer-lambda/infer-progn, rather than one
;;; large typecase. GEN and EMIT= are passed down as function designators since
;;; they close over the constraint accumulator local to one collect-constraints
;;; call, not looked up as free references.

(in-package :cl-cc/type)

;;; ─── per-node-kind constraint generators ──────────────────────────────────

(defun %collect-var (node env)
  (multiple-value-bind (scheme found-p)
      (type-env-lookup (cl-cc/ast:ast-var-name node) env)
    (if found-p
        (instantiate scheme)
        (error 'unbound-variable-error
               :message (format nil "Unbound variable: ~A"
                                (cl-cc/ast:ast-var-name node))
               :variable-name (cl-cc/ast:ast-var-name node)))))

(defun %collect-quote (node)
  (let ((val (cl-cc/ast:ast-quote-value node)))
    (cond ((integerp val) type-int)
          ((stringp  val) type-string)
          ((symbolp  val) type-symbol)
          ((consp    val) type-cons)
          (t +type-unknown+))))

(defun %collect-if (node env gen emit=)
  (let* ((then-ty (funcall gen (cl-cc/ast:ast-if-then node) env))
         (else-ty (funcall gen (cl-cc/ast:ast-if-else node) env))
         (result  (fresh-type-var :name "if")))
    (funcall gen (cl-cc/ast:ast-if-cond node) env)
    (funcall emit= result then-ty)
    (funcall emit= result else-ty)
    result))

(defun %collect-let (node env gen)
  (let ((new-env env))
    (dolist (binding (cl-cc/ast:ast-let-bindings node))
      (let* ((name    (car binding))
             (rhs     (cdr binding))
             (rhs-ty  (funcall gen rhs new-env))
             (scheme  (generalize new-env rhs-ty)))
        (setf new-env (type-env-extend name scheme new-env))))
    (let ((result type-null))
      (dolist (form (cl-cc/ast:ast-let-body node))
        (setf result (funcall gen form new-env)))
      result)))

(defun %collect-lambda (node env gen)
  (let* ((params (cl-cc/ast:ast-lambda-params node))
         (p-types (mapcar (lambda (p)
                             (declare (ignore p))
                             (fresh-type-var :name "p"))
                           params))
         (body-env (type-env-extend*
                     (mapcar (lambda (name ty)
                               (cons name (type-to-scheme ty)))
                             params p-types)
                     env))
         (body-forms (cl-cc/ast:ast-lambda-body node))
         (body-ty (if (null body-forms)
                      type-null
                      (let ((last-ty type-null))
                        (dolist (f body-forms)
                          (setf last-ty (funcall gen f body-env)))
                        last-ty))))
    (make-type-arrow p-types body-ty)))

(defun %collect-call (node env gen emit=)
  (let* ((fn-ty  (funcall gen (cl-cc/ast:ast-call-func node) env))
         (arg-tys (mapcar (lambda (a) (funcall gen a env))
                           (cl-cc/ast:ast-call-args node)))
         (ret-ty (fresh-type-var :name "r")))
    (funcall emit= fn-ty (make-type-arrow arg-tys ret-ty))
    ret-ty))

(defun %collect-progn (node env gen)
  (let ((forms (cl-cc/ast:ast-progn-forms node)))
    (if (null forms)
        type-null
        (let ((result type-null))
          (dolist (f forms)
            (setf result (funcall gen f env)))
          result))))

(defun %collect-defun (node env gen)
  (let* ((params (cl-cc/ast:ast-defun-params node))
         (p-types (mapcar (lambda (p)
                             (declare (ignore p))
                             (fresh-type-var :name "p"))
                           params))
         (body-env (type-env-extend*
                     (mapcar (lambda (name ty)
                               (cons name (type-to-scheme ty)))
                             params p-types)
                     env))
         (body-forms (cl-cc/ast:ast-defun-body node)))
    (dolist (f body-forms)
      (funcall gen f body-env))
    type-symbol))

(defun %collect-defvar (node env gen)
  (when (cl-cc/ast:ast-defvar-value node)
    (funcall gen (cl-cc/ast:ast-defvar-value node) env))
  type-symbol)

(defun %collect-setq (node env gen emit=)
  (let ((val-ty (funcall gen (cl-cc/ast:ast-setq-value node) env)))
    (multiple-value-bind (scheme found-p)
        (type-env-lookup (cl-cc/ast:ast-setq-var node) env)
      (when found-p
        (funcall emit= val-ty (instantiate scheme))))
    val-ty))

;;; ─── collect-constraints ──────────────────────────────────────────────────

(defun collect-constraints (ast env)
  "Generate constraints by walking AST.
Returns (values type constraints) where TYPE is the expected/inferred type
and CONSTRAINTS is a list of constraint structs.

This is a simplified constraint-generation pass: it walks the AST once,
assigns fresh type variables, and emits equality constraints at each node.
The actual solving is done by solve-constraints."
  (let ((constraints nil))
    (labels
        ((emit (c) (push c constraints))
         (emit= (t1 t2) (emit (make-equal-constraint t1 t2)))

         (gen (node env)
           (typecase node
             (cl-cc/ast:ast-int type-int)
             (cl-cc/ast:ast-var    (%collect-var node env))
             (cl-cc/ast:ast-quote  (%collect-quote node))
             (cl-cc/ast:ast-if     (%collect-if node env #'gen #'emit=))
             (cl-cc/ast:ast-let    (%collect-let node env #'gen))
             (cl-cc/ast:ast-lambda (%collect-lambda node env #'gen))
             (cl-cc/ast:ast-call   (%collect-call node env #'gen #'emit=))
             (cl-cc/ast:ast-progn  (%collect-progn node env #'gen))
             (cl-cc/ast:ast-defun  (%collect-defun node env #'gen))
             (cl-cc/ast:ast-defvar (%collect-defvar node env #'gen))
             (cl-cc/ast:ast-setq   (%collect-setq node env #'gen #'emit=))
             (t (fresh-type-var :name "?")))))

      (let ((ty (gen ast env)))
        (values ty (nreverse constraints))))))
