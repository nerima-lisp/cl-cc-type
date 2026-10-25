(in-package #:cl-cc/type/checking/test)

(describe "checking feature"
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/checking/bidirectional-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/checking/checker-test.lisp")))
