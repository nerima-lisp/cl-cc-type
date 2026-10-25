(in-package #:cl-cc/type/inference/test)

(describe "inference feature"
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/inference-effect-tests.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/inference-forms-advanced-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/inference-forms-tests.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/inference-tests.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/solver-collect-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/type-inference-tests.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/type-system-inference-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/phase-integration-test.lisp"))
                     (load
                      (asdf:system-relative-pathname "cl-cc-type/test"
                                                     "t/inference/formatter-edge-cases-test.lisp")))
