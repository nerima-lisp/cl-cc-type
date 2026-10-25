(in-package #:cl-cc/type/capabilities/test)

(describe "capabilities feature tests"
  (load (asdf:system-relative-pathname
         "cl-cc-type/test" "t/capabilities/capabilities-test.lisp")))
