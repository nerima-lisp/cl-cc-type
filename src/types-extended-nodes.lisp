;;;; types-extended-nodes.lisp
;;;; Effect/GADT/constraint structs, singletons, type-equal-p, type-children,
;;;; type-free-vars
(in-package :cl-cc/type)

;;; ─── type-effect-row ──────────────────────────────────────────────────────

(defstruct (type-effect-row (:include type-node))
  "An effect row <ε₁, …, εₙ | ρ>.
EFFECTS: list of type-effect-op (concrete effect labels/applications).
ROW-VAR: an open row variable (type-var) or nil for closed rows."
  (effects nil :type list)
  (row-var nil))

(defvar +pure-effect-row+ (make-type-effect-row :effects nil :row-var nil)
  "The empty (pure) closed effect row.")

;;; ─── type-effect-op ───────────────────────────────────────────────────────

(defstruct (type-effect-op (:include type-node))
  "A single (possibly applied) effect label.
NAME: the effect name symbol (e.g., 'IO, 'STATE).
ARGS: type arguments (e.g., (list type-int) for (State Int))."
  (name nil :type symbol)
  (args nil :type list))

;;; ─── type-handler ─────────────────────────────────────────────────────────

(defstruct (type-handler (:include type-node))
  "The type of an effect handler.
EFFECT:   the effect being handled (type-effect-op).
INPUT:    the type of the handled computation's result.
OUTPUT:   the overall return type after handling."
  (effect nil)
  (input  nil)
  (output nil))

;;; ─── type-gadt-con ────────────────────────────────────────────────────────

(defstruct (type-gadt-con (:include type-node))
  "A GADT constructor type — carries its index constraint.
NAME:       the constructor name symbol.
ARG-TYPES:  list of argument types.
INDEX-TYPE: the index type (the return type's type parameter)."
  (name       nil :type symbol)
  (arg-types  nil :type list)
  (index-type nil))

;;; ─── type-constraint ──────────────────────────────────────────────────────

(defstruct (type-constraint (:include type-node))
  "A typeclass constraint C T — the constraint that T has an instance of class C.
CLASS-NAME: the typeclass symbol (e.g., 'EQ, 'NUM, 'SHOW).
TYPE-ARG:   the constrained type (often a type-var)."
  (class-name nil :type symbol)
  (type-arg   nil))

;;; ─── type-qualified ───────────────────────────────────────────────────────

(defstruct (type-qualified (:include type-node)
                           (:constructor %make-type-qualified-raw))
  "A type qualified by typeclass constraints: (C₁ a, C₂ b) => T.
CONSTRAINTS: list of type-constraint.
BODY:        the underlying type."
  (constraints nil :type list)
  (body        nil))

(defun make-type-qualified (&key constraints body)
  "Constructor for type-qualified using the canonical :body slot."
  (%make-type-qualified-raw :constraints constraints :body body))

;;; ─── type-error ───────────────────────────────────────────────────────────

(defstruct (type-error (:include type-node))
  "Error sentinel produced during type inference for error recovery.
MESSAGE: a human-readable description of the type error."
  (message "" :type string))

;;; ─── Well-known primitive singletons ──────────────────────────────────────

(defvar type-int     (make-type-primitive :name 'fixnum)  "fixnum type.")
(defvar type-float   (make-type-primitive :name 'float)   "float type.")
(defvar type-string  (make-type-primitive :name 'string)  "string type.")
(defvar type-bool    (make-type-primitive :name 'boolean) "boolean type.")
(defvar type-symbol  (make-type-primitive :name 'symbol)  "symbol type.")
(defvar type-cons    (make-type-primitive :name 'cons)    "cons type.")
(defvar type-null    (make-type-primitive :name 'null)    "null/nil type.")
(defvar type-any     (make-type-primitive :name 't)       "top type (any).")
(defvar type-char    (make-type-primitive :name 'character) "character type.")
(defvar type-unit    (make-type-primitive :name 'null)    "unit type (alias null).")

(%initialize-advanced-dispatch-registries)

;;; ─── Effect row singletons ────────────────────────────────────────────────

(defvar +io-effect-row+
  (make-type-effect-row
   :effects (list (make-type-effect-op :name 'io))
   :row-var nil)
  "Closed IO effect row.")

;;; ─── Type equality (structural) ───────────────────────────────────────────

(defun %type-list-equal-p (ls1 ls2)
  "True iff LS1 and LS2 have equal length and pairwise type-equal-p elements."
  (and (= (length ls1) (length ls2))
       (every #'type-equal-p ls1 ls2)))

(defgeneric type-equal-p (t1 t2)
  (:documentation "Structural equality of two types (no substitution applied).
Type-error nodes are never considered equal (each represents a distinct error point),
even if they happen to be the same object.")
  (:method (t1 t2) nil))

(defmethod type-equal-p :around (t1 t2)
  (cond
    ((or (type-error-p t1) (type-error-p t2)) nil)   ; errors always distinct
    ((eq t1 t2) t)
    (t (call-next-method))))

(defmethod type-equal-p ((t1 type-primitive) (t2 type-primitive))
  (eq (type-primitive-name t1) (type-primitive-name t2)))

(defmethod type-equal-p ((t1 type-var) (t2 type-var))
  (type-var-equal-p t1 t2))

(defmethod type-equal-p ((t1 type-rigid) (t2 type-rigid))
  (type-rigid-equal-p t1 t2))

(defmacro define-type-equal-p (type-class &rest field-specs)
  "Define a TYPE-EQUAL-P method for TYPE-CLASS that ANDs together one
comparison per FIELD-SPECS entry. Each entry is (ACCESSOR COMPARATOR); the
method returns (AND (COMPARATOR (ACCESSOR T1) (ACCESSOR T2)) ...) across all
entries. Methods whose per-field comparison is not a plain two-argument call
— TYPE-EFFECT-ROW's row-var, which falls back from TYPE-EQUAL-P to EQ when
either side is absent — are left hand-written."
  `(defmethod type-equal-p ((t1 ,type-class) (t2 ,type-class))
     (and ,@(mapcar (lambda (spec)
                       (destructuring-bind (accessor comparator) spec
                         `(,comparator (,accessor t1) (,accessor t2))))
                     field-specs))))

(define-type-equal-p type-arrow
  (type-arrow-params %type-list-equal-p)
  (type-arrow-return type-equal-p)
  (type-arrow-mult eq))

(defmethod type-equal-p ((t1 type-product) (t2 type-product))
  (%type-list-equal-p (type-product-elems t1) (type-product-elems t2)))

(defmethod type-equal-p ((t1 type-union) (t2 type-union))
  (%type-list-equal-p (type-union-types t1) (type-union-types t2)))

(defmethod type-equal-p ((t1 type-intersection) (t2 type-intersection))
  (%type-list-equal-p (type-intersection-types t1) (type-intersection-types t2)))

(define-type-equal-p type-forall
  (type-forall-var type-var-equal-p)
  (type-forall-body type-equal-p))

(define-type-equal-p type-exists
  (type-exists-var type-var-equal-p)
  (type-exists-body type-equal-p))

(define-type-equal-p type-app
  (type-app-fun type-equal-p)
  (type-app-arg type-equal-p))

(define-type-equal-p type-mu
  (type-mu-var type-var-equal-p)
  (type-mu-body type-equal-p))

(define-type-equal-p type-linear
  (type-linear-grade eq)
  (type-linear-base type-equal-p))

(define-type-equal-p type-refinement
  (type-refinement-base type-equal-p)
  (type-refinement-predicate equal))

(defmethod type-equal-p ((t1 type-effect-row) (t2 type-effect-row))
  (and (%type-list-equal-p (type-effect-row-effects t1) (type-effect-row-effects t2))
       (let ((rv1 (type-effect-row-row-var t1))
             (rv2 (type-effect-row-row-var t2)))
         (if (and rv1 rv2) (type-equal-p rv1 rv2) (eq rv1 rv2)))))

(define-type-equal-p type-effect-op
  (type-effect-op-name eq)
  (type-effect-op-args %type-list-equal-p))

(define-type-equal-p type-advanced
  (type-advanced-feature-id string=)
  (type-advanced-args type-advanced-payload-equal-p)
  (type-advanced-properties type-advanced-properties-equal-p)
  (type-advanced-evidence type-advanced-payload-equal-p))

(define-type-equal-p type-constraint
  (type-constraint-class-name eq)
  (type-constraint-type-arg type-equal-p))

(define-type-equal-p type-qualified
  (type-qualified-constraints %type-list-equal-p)
  (type-qualified-body type-equal-p))

;;; ─── Structural traversal helpers ──────────────────────────────────────────

(defun type-bound-var (ty)
  "Return the type variable bound by TY, or NIL when TY is not a binder.
This is the shared data-layer hook used by traversal code like type-free-vars."
  (typecase ty
    (type-forall (type-forall-var ty))
    (type-exists (type-exists-var ty))
    (type-lambda (type-lambda-var ty))
    (type-mu     (type-mu-var ty))
    (t nil)))

(defgeneric type-children (ty)
  (:documentation "Return TY's immediate child types as a flat list.
The function is intentionally structural and side-effect free so traversal logic
can live elsewhere (free vars, occurs check, zonking, printers, etc.).")
  (:method ((ty null)) nil)
  (:method (ty) nil))

;;; DEFINE-TYPE-CHILDREN covers the common case: a node whose children are
;;; exactly the contents of one accessor, with no optional fields or extra
;;; accessors to fold in. LIST-VALUED marks an accessor that already returns
;;; a list (copied, so a caller can mutate the result without aliasing TY's
;;; own storage); otherwise the accessor's single result is wrapped in a
;;; fresh list. Nodes whose children come from more than one accessor, or
;;; include an optional field (arrow, record, variant, effect-row, advanced,
;;; handler, gadt-con, qualified), have real per-node logic and stay
;;; hand-written below, the same boundary DEFINE-REGISTRY draws in
;;; registry.lisp between a plain accessor and one with work behind it.
(defmacro define-type-children (type-class field-accessor &key list-valued)
  `(defmethod type-children ((ty ,type-class))
     ,(if list-valued
          `(copy-list (,field-accessor ty))
          `(list (,field-accessor ty)))))

(defmethod type-children ((ty type-arrow))
  (append (type-arrow-params ty)
          (list (type-arrow-return ty))
          (when (type-arrow-effects ty)
            (list (type-arrow-effects ty)))))

(define-type-children type-product type-product-elems :list-valued t)

(defmethod type-children ((ty type-record))
  (append (mapcar #'cdr (type-record-fields ty))
          (when (type-record-row-var ty)
            (list (type-record-row-var ty)))))

(defmethod type-children ((ty type-variant))
  (append (mapcar #'cdr (type-variant-cases ty))
          (when (type-variant-row-var ty)
            (list (type-variant-row-var ty)))))

(define-type-children type-union type-union-types :list-valued t)
(define-type-children type-intersection type-intersection-types :list-valued t)
(define-type-children type-forall type-forall-body)
(define-type-children type-exists type-exists-body)

(defmethod type-children ((ty type-app))
  (list (type-app-fun ty) (type-app-arg ty)))

(define-type-children type-lambda type-lambda-body)
(define-type-children type-mu type-mu-body)
(define-type-children type-refinement type-refinement-base)
(define-type-children type-linear type-linear-base)
(define-type-children type-capability type-capability-base)

(defmethod type-children ((ty type-effect-row))
  (append (copy-list (type-effect-row-effects ty))
          (when (type-effect-row-row-var ty)
            (list (type-effect-row-row-var ty)))))

(define-type-children type-effect-op type-effect-op-args :list-valued t)

(defmethod type-children ((ty type-advanced))
  (append (mapcan #'type-advanced-payload-children (type-advanced-args ty))
          (mapcan #'type-advanced-payload-children (type-advanced-properties ty))
          (type-advanced-payload-children (type-advanced-evidence ty))))

(defmethod type-children ((ty type-handler))
  (list (type-handler-effect ty)
        (type-handler-input ty)
        (type-handler-output ty)))

(defmethod type-children ((ty type-gadt-con))
  (append (copy-list (type-gadt-con-arg-types ty))
          (when (type-gadt-con-index-type ty)
            (list (type-gadt-con-index-type ty)))))

(define-type-children type-constraint type-constraint-type-arg)

(defmethod type-children ((ty type-qualified))
  (append (copy-list (type-qualified-constraints ty))
          (list (type-qualified-body ty))))

;;; ─── Free type variables ──────────────────────────────────────────────────

(defun %type-free-vars-list (t0)
  "Collect the (possibly-duplicated) list of free type-var nodes in T0."
  (cond
    ((type-var-p t0) (list t0))
    (t
     (let* ((bound-var  (type-bound-var t0))
            (child-vars (mapcan #'%type-free-vars-list (type-children t0))))
       (if bound-var
           (remove-if (lambda (v) (type-var-equal-p v bound-var)) child-vars)
           child-vars)))))

(defun type-free-vars (ty)
  "Return the deduplicated list of free type-var nodes in TY."
  (remove-duplicates (%type-free-vars-list ty) :test #'type-var-equal-p))
