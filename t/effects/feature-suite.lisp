(in-package #:cl-cc/type/effects/test)

(describe "cl-cc/type/effects"
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/effects/effect-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/effects/effects-additional-test.lisp"))
  (load (asdf:system-relative-pathname "cl-cc-type/test" "t/effects/phase-integration-test.lisp")))
