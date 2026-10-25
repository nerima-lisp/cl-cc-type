;;;; types-extended-security-labels.lisp — Security-label lattice and labeled-value taint tracking

(in-package :cl-cc/type)

(defparameter +security-label-order+
  '(:public :trusted :tainted :secret :top-secret)
  "Concrete information-flow lattice from least to most restrictive.")

(define-keyword-normalizer normalize-security-label (label)
  "Normalize LABEL into a keyword designator.")

(defun security-label-rank (label)
  "Return LABEL's lattice rank, or NIL when unknown."
  (position (normalize-security-label label) +security-label-order+))

(defun security-label-p (label)
  "Return T when LABEL is part of the security lattice."
  (not (null (security-label-rank label))))

(defun security-label<= (source target)
  "Return T when information at SOURCE may flow into TARGET."
  (let ((source-rank (security-label-rank source))
        (target-rank (security-label-rank target)))
    (and source-rank target-rank (<= source-rank target-rank))))

(defun join-security-labels (left right)
  "Return the least upper bound of LEFT and RIGHT."
  (let* ((left-label (normalize-security-label left))
         (right-label (normalize-security-label right))
         (left-rank (security-label-rank left-label))
         (right-rank (security-label-rank right-label)))
    (unless (and left-rank right-rank)
      (error "Unknown security labels ~S and ~S" left right))
    (nth (max left-rank right-rank) +security-label-order+)))

(defun meet-security-labels (left right)
  "Return the greatest lower bound of LEFT and RIGHT."
  (let* ((left-label (normalize-security-label left))
         (right-label (normalize-security-label right))
         (left-rank (security-label-rank left-label))
         (right-rank (security-label-rank right-label)))
    (unless (and left-rank right-rank)
      (error "Unknown security labels ~S and ~S" left right))
    (nth (min left-rank right-rank) +security-label-order+)))

(defstruct (labeled-value (:constructor %make-labeled-value))
  "A concrete security-labeled runtime value."
  (value nil)
  (label :public)
  (tainted-p nil :type boolean)
  (audit-trail nil :type list))

(defun make-labeled-value (value label &key tainted-p audit-trail)
  "Construct a labeled VALUE with LABEL and optional taint/audit data."
  (unless (security-label-p label)
    (error "Unknown security label: ~S" label))
  (%make-labeled-value :value value
                       :label (normalize-security-label label)
                       :tainted-p (not (null tainted-p))
                       :audit-trail (copy-list audit-trail)))

(defun labeled-value-flow-allowed-p (value-or-label target-label)
  "Return T when VALUE-OR-LABEL may flow to TARGET-LABEL."
  (let ((source-label (if (labeled-value-p value-or-label)
                          (labeled-value-label value-or-label)
                          value-or-label)))
    (security-label<= source-label target-label)))

(defun sanitize-labeled-value (labeled-value sanitizer &key audit-entry)
  "Return a sanitized copy of LABELED-VALUE with taint cleared.
SANITIZER may be NIL, in which case the original payload is preserved."
  (unless (labeled-value-p labeled-value)
    (error "Expected labeled-value, got ~S" labeled-value))
  (let ((sanitized (if sanitizer
                       (funcall sanitizer (labeled-value-value labeled-value))
                       (labeled-value-value labeled-value))))
    (make-labeled-value sanitized
                        (labeled-value-label labeled-value)
                        :tainted-p nil
                        :audit-trail (append (labeled-value-audit-trail labeled-value)
                                             (when audit-entry (list audit-entry))))))

(defun declassify-labeled-value (labeled-value target-label reason)
  "Return a copy of LABELED-VALUE declassified to TARGET-LABEL.
REASON must be present and the target must not be more restrictive than the source."
  (unless (labeled-value-p labeled-value)
    (error "Expected labeled-value, got ~S" labeled-value))
  (unless reason
    (error "Declassification requires an explicit reason"))
  (unless (security-label-p target-label)
    (error "Unknown target security label: ~S" target-label))
  (let ((source (labeled-value-label labeled-value))
        (target (normalize-security-label target-label)))
    (unless (security-label<= target source)
      (error "Cannot declassify from ~S to more restrictive label ~S" source target))
    (make-labeled-value (labeled-value-value labeled-value)
                        target
                        :tainted-p (labeled-value-tainted-p labeled-value)
                        :audit-trail (append (labeled-value-audit-trail labeled-value)
                                             (list (list :declassify source target reason))))))
