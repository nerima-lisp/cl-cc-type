;;;; types-extended-advanced-node.lisp — The type-advanced struct and its property accessors
(in-package :cl-cc/type)

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

(defun %type-advanced-normalize-graded-keyword-arg (feature-id args properties)
  "Turn (graded :grade T) parsed as a keyword property back into positional args."
  (if (and (member feature-id '("FR-3401" "FR-3402") :test #'string=)
           (null args)
           (= (length properties) 1))
      (let ((entry (first properties)))
        (values (list (car entry) (cdr entry)) nil))
      (values args properties)))

(defun type-advanced-property (advanced property &optional default)
  "Return ADVANCED's PROPERTY value, or DEFAULT when absent."
  (let ((cell (assoc property (type-advanced-properties advanced) :test #'equal)))
    (if cell (cdr cell) default)))

(defun type-advanced-property-present-p (advanced property)
  "Return T when ADVANCED contains PROPERTY."
  (not (null (assoc property (type-advanced-properties advanced) :test #'equal))))

(define-keyword-normalizer %type-advanced-normalize-symbol-keyword (value)
  "Normalize VALUE into a keyword by symbol/string name when possible.")

(defun %type-advanced-label-rank (label)
  "Return LABEL's rank in the advanced information-flow lattice."
  (security-label-rank label))

(defun type-advanced-security-label<= (source target)
  "Return T when information at SOURCE may flow to TARGET."
  (security-label<= source target))

(defun %type-advanced-head-name (value)
  "Return VALUE's list-head symbol name when VALUE is a cons form."
  (and (consp value)
       (symbolp (first value))
       (symbol-name (first value))))

(defun %type-advanced-payload-security-label (value)
  "Return the explicit security label encoded by VALUE, if any."
  (let ((head (%type-advanced-head-name value)))
    (cond
      ((null head) nil)
      ((string= head "PUBLIC") :public)
      ((string= head "TRUSTED") :trusted)
      ((string= head "TAINTED") :tainted)
      ((string= head "SECRET") :secret)
      ((string= head "TOP-SECRET") :top-secret)
      (t nil))))

(defun %type-advanced-multiplicity-p (value)
  "Return T when VALUE is a supported multiplicity/grade designator."
  (grade-designator-p value))

(defun type-advanced-route-p (value)
  "Return T when VALUE is a well-formed route payload for FR-3305."
  (or (and (route-p value) (route-valid-p value))
      (route-form-valid-p value)))
