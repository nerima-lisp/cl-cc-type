(in-package #:cl-cc/type/advanced-metadata/test)

(describe "cl-cc/type/advanced-metadata"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/advanced-metadata/advanced-node-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/advanced-metadata/contract-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/advanced-metadata/init-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/advanced-metadata/meta-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/advanced-metadata/meta-validators-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/advanced-metadata/validate-test.lisp")))
