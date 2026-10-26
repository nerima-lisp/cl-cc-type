(in-package #:cl-cc/type/rows/test)

(describe "cl-cc/type/rows"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/rows/row-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/rows/rows-printer-test.lisp")))
