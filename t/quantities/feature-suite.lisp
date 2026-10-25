(in-package #:cl-cc/type/quantities/test)

(describe "cl-cc/type/quantities"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/quantities/multiplicity-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/quantities/qtt-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/quantities/quantities-additional-test.lisp")))
