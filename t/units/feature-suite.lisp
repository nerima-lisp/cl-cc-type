(in-package #:cl-cc/type/units/test)

(describe "cl-cc/type/units"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/units/advanced-units-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/units/units-test.lisp")))
