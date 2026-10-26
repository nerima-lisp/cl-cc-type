(in-package #:cl-cc/type/exhaustiveness/test)

(describe "exhaustiveness feature"
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/exhaustiveness/exhaustiveness-test.lisp")))
