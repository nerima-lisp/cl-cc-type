(in-package #:cl-cc/type/routing/test)

(describe "cl-cc/type/routing"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/routing/routing-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/routing/types-extended-routing-types-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/routing/advanced-route-valid-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/routing/advanced-route-invalid-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/routing/advanced-route-predicate-test.lisp")))
