(in-package #:cl-cc/type/ffi/test)

(describe "cl-cc/type/ffi"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/ffi/advanced-ffi-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/ffi/ffi-test.lisp")))
