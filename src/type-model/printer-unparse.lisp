;;;; printer-unparse.lisp — type unparsing and type-specifier recognition

(in-package :cl-cc/type/type-model)

(defun %unparse-advanced-value (value)
  "Recursively unparse nested type-node payload values."
  (cond
    ((typep value 'type-node) (unparse-type value))
    ((consp value)
     (cons (%unparse-advanced-value (car value))
           (%unparse-advanced-value (cdr value))))
    (t value)))

(defun %unparse-type-advanced (ty)
  "Unparse a type-advanced node back into its surface s-expression form."
  (let* ((surface-head (type-advanced-name ty))
         (feature-id (intern (type-advanced-feature-id ty)
                             (or (and (symbolp surface-head) (symbol-package surface-head))
                                 *package*)))
         (args (mapcar #'%unparse-advanced-value (type-advanced-args ty)))
         (properties
           (mapcan (lambda (entry)
                     (list (car entry) (%unparse-advanced-value (cdr entry))))
                   (type-advanced-properties ty)))
         (evidence (when (type-advanced-evidence ty)
                     (list :evidence
                           (%unparse-advanced-value (type-advanced-evidence ty))))))
    (if (and (symbolp surface-head)
             (not (string= (symbol-name surface-head) "ADVANCED")))
        `(,surface-head ,@args ,@properties ,@evidence)
        `(,surface-head ,feature-id ,@args ,@properties ,@evidence))))

(defmethod unparse-type ((ty type-node))
  "Convert a type-node back to a type specifier s-expression."
  (typecase ty
    (type-primitive (type-primitive-name ty))
    (type-var
     (if (type-var-name ty)
         (type-var-name ty)
         (intern (format nil "?T~D" (type-var-id ty)))))
    (type-arrow
     `(-> ,@(mapcar #'unparse-type (type-arrow-params ty))
          ,(unparse-type (type-arrow-return ty))))
    (type-product
     `(values ,@(mapcar #'unparse-type (type-product-elems ty))))
    (type-union
     (let ((name (type-union-constructor-name ty)))
       (if name
           `(,name ,@(mapcar #'unparse-type (type-constructor-args ty)))
           `(or ,@(mapcar #'unparse-type (type-union-types ty))))))
    (type-intersection
     `(and ,@(mapcar #'unparse-type (type-intersection-types ty))))
    (type-forall
     `(forall ,(type-var-name (type-forall-var ty))
              ,(unparse-type (type-forall-body ty))))
    (type-app
     (let ((name (type-constructor-name ty))
           (args (type-constructor-args ty)))
       (if name
           `(,name ,@(mapcar #'unparse-type args))
           (list (unparse-type (type-app-fun ty))
                 (unparse-type (type-app-arg ty))))))
    (type-advanced (%unparse-type-advanced ty))
    (t ty)))
