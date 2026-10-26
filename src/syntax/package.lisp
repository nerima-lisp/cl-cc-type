;;;; Syntax protocol package.

(defpackage :cl-cc/type/syntax
  (:use #:cl)
  (:export
   #:parse-type-specifier
   #:type-to-string
   #:unparse-type
   #:looks-like-type-specifier-p))
