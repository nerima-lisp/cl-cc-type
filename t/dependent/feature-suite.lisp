(in-package #:cl-cc/type/dependent/test)

(describe "cl-cc/type/dependent"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/dependent/advanced-dependent-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/dependent/dependent-test.lisp")))
