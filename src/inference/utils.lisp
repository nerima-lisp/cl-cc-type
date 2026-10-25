;;;; utils.lisp — FR-1804 printf-style format-type inference

(in-package :cl-cc/type)

(defun %format-directive-type (directive)
  (case directive
    ((#\D #\B #\O #\X) type-int)
    ((#\F #\E #\G #\$) type-float)
    ((#\S #\A) type-string)
    ((#\C) type-char)
    (otherwise nil)))

(defun format-type (control-string)
  "Infer a FR-1804 printf-style function type from CONTROL-STRING."
  (unless (stringp control-string)
    (error "format-type expects a literal control string"))
  (let ((params nil)
        (length (length control-string))
        (index 0))
    (loop while (< index length) do
      (let ((char (char control-string index)))
        (if (char= char #\~)
            (progn
              (incf index)
              (when (< index length)
                (let ((directive (char-upcase (char control-string index))))
                  (cond
                    ((char= directive #\~) nil)
                    ((%format-directive-type directive)
                     (push (%format-directive-type directive) params))
                    (t (error "Unsupported format directive ~~A" directive))))))
            nil))
      (incf index))
    (make-type-arrow (nreverse params) type-string)))
