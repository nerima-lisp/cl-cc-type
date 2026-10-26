(in-package #:cl-cc/type/subtyping/test)

(describe "subtyping feature"
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/subtyping/subtyping-extended-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/subtyping/subtyping-test.lisp")))
