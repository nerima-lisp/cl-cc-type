;;;; inference.lisp - HM Inference Helpers
;;;
;;; Contains: %infer-fn-binding, %find-fn-type-declaration.
;;;
;;; Load order: before inference-handlers.lisp.

(in-package :cl-cc/type/inference)

;;; NOTE: *type-var-counter*, fresh-type-var, reset-type-vars! are defined
;;;       in representation.lisp.
;;;       type-env struct and type-env-{empty,lookup,extend,extend*,to-alist,free-vars}
;;;       are defined in representation.lisp.
;;;       dict-env-extend / dict-env-lookup are defined in typeclass.lisp.
;;;       Do NOT redefine any of those here.

;;; Helpers

(defun %infer-fn-binding (binding lookup-env result-env)
  "Infer the type scheme for a single (name params . body) binding and extend RESULT-ENV.
   Parameters are looked up in LOOKUP-ENV (= parent env for flet, = mutual env for labels).
   Returns the new type environment."
  (let* ((name         (first binding))
         (params       (second binding))
         (body         (cddr binding))
         (param-types  (loop repeat (length params) collect (fresh-type-var)))
         (param-env    (type-env-extend* (mapcar (lambda (pname ptype)
                                                   (cons pname (make-type-scheme nil ptype)))
                                                 params param-types)
                                         lookup-env)))
    (multiple-value-bind (body-type subst) (infer-body body param-env)
      (let* ((fn-type (make-type-arrow-raw
                       :params (mapcar (lambda (p) (zonk p subst)) param-types)
                       :return body-type))
        (scheme  (generalize result-env fn-type)))
        (type-env-extend name scheme result-env)))))

;;; FR-004: Polymorphic Recursion Helpers

(defun %find-fn-type-declaration (fn-name declarations)
  "Scan DECLARATIONS for (type type-spec fn-name ...) and return type-spec.
   DECLARATIONS is the list from ast-callable-declarations.
   Returns a type specifier s-expression, or nil if not found."
  (when fn-name
    (loop for decl in declarations
          when (and (consp decl)
                    (eq (car decl) 'type)
                    (>= (length decl) 3)
                    (member fn-name (cddr decl) :test #'eq))
          return (second decl))))

;;; infer-* handlers, dispatcher (infer), and infer-binop → see inference-handlers.lisp
