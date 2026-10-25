;;;; Public generic dispatch tests for the type syntax protocol.

(in-package :cl-cc/type/syntax/test)

(defclass syntax-dispatch-fixture () ())

(defmethod parse-type-specifier ((value syntax-dispatch-fixture))
  (declare (ignore value))
  :parsed)

(defmethod type-to-string ((value syntax-dispatch-fixture))
  (declare (ignore value))
  "rendered")

(defmethod unparse-type ((value syntax-dispatch-fixture))
  (declare (ignore value))
  :unparsed)

(defmethod looks-like-type-specifier-p ((value syntax-dispatch-fixture))
  (declare (ignore value))
  t)

(it-sequential "parse-type-specifier dispatches to a local class method"
  (expect (parse-type-specifier (make-instance 'syntax-dispatch-fixture))
          :to-equal :parsed))

(it-sequential "type-to-string keeps its one-argument generic contract"
  (expect (type-to-string (make-instance 'syntax-dispatch-fixture))
          :to-equal "rendered"))

(it-sequential "unparse-type dispatches to a local class method"
  (expect (unparse-type (make-instance 'syntax-dispatch-fixture))
          :to-equal :unparsed))

(it-sequential "looks-like-type-specifier-p dispatches to a local class method"
  (expect (looks-like-type-specifier-p (make-instance 'syntax-dispatch-fixture))
          :to-be-truthy))
