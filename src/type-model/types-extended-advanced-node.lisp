;;;; types-extended-advanced-node.lisp — The type-advanced struct and its property accessors
(in-package :cl-cc/type/type-model)

(defstruct (type-advanced (:include type-node) (:constructor %make-type-advanced))
  "Validated carrier for advanced feature families."
  (feature-id "" :type string)
  (name 'advanced :type symbol)
  (args nil :type list)
  (properties nil :type list)
  (evidence nil))

(defun %type-advanced-property-sort-key (entry)
  "Return a stable textual sort key for an advanced property ENTRY."
  (let ((key (if (consp entry) (car entry) entry)))
    (if (symbolp key)
        (symbol-name key)
        (prin1-to-string key))))

(defun %type-advanced-normalize-properties (properties)
  "Return PROPERTIES in deterministic alist-key order."
  (stable-sort (copy-list properties)
               #'string<
               :key #'%type-advanced-property-sort-key))

(defun type-advanced-property (advanced property &optional default)
  "Return ADVANCED's PROPERTY value, or DEFAULT when absent."
  (let ((cell (assoc property (type-advanced-properties advanced) :test #'equal)))
    (if cell (cdr cell) default)))

(defun type-advanced-property-present-p (advanced property)
  "Return T when ADVANCED contains PROPERTY."
  (not (null (assoc property (type-advanced-properties advanced) :test #'equal))))

(define-keyword-normalizer %type-advanced-normalize-symbol-keyword (value)
  "Normalize VALUE into a keyword by symbol/string name when possible.")

