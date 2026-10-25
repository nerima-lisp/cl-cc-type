(in-package #:cl-cc/type-test-support)

(defun internal-symbol (package-name symbol-name)
  (let ((package (find-package (string-upcase package-name))))
    (unless package
      (error "No package named ~S" package-name))
    (multiple-value-bind (symbol status) (find-symbol symbol-name package)
      (unless (and symbol (eq status :internal))
        (error "~S is not an internal symbol in package ~A" symbol-name package))
      symbol)))

(defun internal-function (package-name symbol-name)
  (let ((symbol (internal-symbol package-name symbol-name)))
    (unless (fboundp symbol)
      (error "~S is not fbound in package ~A" symbol-name package-name))
    (symbol-function symbol)))
