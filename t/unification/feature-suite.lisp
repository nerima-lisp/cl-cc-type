(in-package #:cl-cc/type/unification/test)

(describe "unification feature"
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/constraint-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/solver-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/substitution-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/substitution-zonk-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/unification-advanced-nodes-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/unification-effect-rows-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/unification/unification-test.lisp")))
