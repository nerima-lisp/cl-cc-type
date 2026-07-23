;;;; run-compile-check.lisp
;;;;
;;;; Compile and load :cl-cc-type from the current source tree, then exit
;;;; non-zero on any compile/load error. This is the build and CI gate.
;;;;
;;;; cl-cc-type depends on :cl-cc-ast. Its source root is supplied via the
;;;; CL_CC_AST_ROOT environment variable (set by flake.nix from the cl-cc-ast
;;;; flake input); both trees are registered on the ASDF source registry.

(require :asdf)

(let ((ast-root (uiop:getenv "CL_CC_AST_ROOT")))
  (unless ast-root
    (format t "~&FAIL cl-cc-type: CL_CC_AST_ROOT is not set~%")
    (finish-output)
    (sb-ext:exit :code 1))
  (asdf:initialize-source-registry
   `(:source-registry
     (:tree ,(truename "."))
     (:tree ,(truename ast-root))
     :inherit-configuration)))

(handler-case
    (progn
      (asdf:load-system :cl-cc-type)
      (format t "~&PASS cl-cc-type compile check~%")
      (finish-output))
  (error (e)
    (format t "~&FAIL cl-cc-type: ~a~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))
