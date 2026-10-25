;;;; types-level-strings.lisp — FR-1702 type-level strings and template literals

(in-package :cl-cc/type)

(defun make-type-level-string (value)
  "Construct a FR-1702 type-level string/symbol node."
  (unless (stringp value)
    (error "Type-level string must be a string, got ~S" value))
  (make-type-advanced :feature-id "FR-1702" :name 'symbol-kind :args (list value)))

(defun type-level-string-p (type)
  "Return T when TYPE is a FR-1702 string/symbol-kind node."
  (and (type-advanced-p type)
       (string= (type-advanced-feature-id type) "FR-1702")))

(defun type-level-string-value (type)
  "Return TYPE's type-level string value."
  (cond
    ((stringp type) type)
    ((and (type-level-string-p type)
          (stringp (first (type-advanced-args type))))
     (first (type-advanced-args type)))
    (t (error "String value is not statically known: ~S" type))))

(defun has-field-type (field-name field-type)
  "Construct a FR-1702 named-field requirement."
  (make-type-advanced :feature-id "FR-1702"
                      :name 'has-field
                      :args (list field-name field-type)))

(defun %field-name= (left right)
  (string= (string-upcase (if (symbolp left) (symbol-name left) (princ-to-string left)))
           (string-upcase (if (symbolp right) (symbol-name right) (princ-to-string right)))))

(defun get-field-type (field-name record-type)
  "Return FIELD-NAME's type from RECORD-TYPE or signal a type error."
  (unless (type-record-p record-type)
    (error "get-field-type expects a record type, got ~S" record-type))
  (let ((entry (find field-name (type-record-fields record-type)
                     :key #'car :test #'%field-name=)))
    (unless entry
      (error "Record type does not contain field ~S" field-name))
    (cdr entry)))

(defun template-literal-type (&rest parts)
  "Construct a FR-1702 template literal type by concatenating static PARTS."
  (make-type-level-string
   (apply #'concatenate 'string
          (mapcar (lambda (part)
                    (if (type-level-string-p part)
                        (type-level-string-value part)
                        (princ-to-string part)))
                  parts))))
