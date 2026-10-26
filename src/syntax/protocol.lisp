;;;; Public syntax protocol for type parsing and rendering.

(in-package :cl-cc/type/syntax)

(defgeneric parse-type-specifier (specifier)
  (:documentation "Parse a type specifier into a type representation."))

(defgeneric type-to-string (type)
  (:documentation "Render a type representation as a string.")
  (:method (type)
    (format nil "#<type ~A>" (type-of type))))

(defgeneric unparse-type (type)
  (:documentation "Convert a type representation to a type specifier.")
  (:method (type) type))

(defgeneric looks-like-type-specifier-p (form)
  (:documentation "Return true when FORM has the shape of a type specifier."))
