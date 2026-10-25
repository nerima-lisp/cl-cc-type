(in-package #:cl-cc/type/security-labels/test)

(describe "cl-cc/type/security-labels"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/security-labels/advanced-security-labels-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/security-labels/security-labels-test.lisp")))
