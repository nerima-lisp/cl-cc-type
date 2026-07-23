;;;; run-tests.lisp — load :cl-cc-type-test and run the cl-weave suite.
;;;;
;;;; ASDF resolves the dependency chain (cl-cc-type-test -> cl-cc-type ->
;;;; cl-cc-ast, plus cl-weave) from the source registry. The external source
;;;; roots are supplied via environment variables set by flake.nix:
;;;;   CL_CC_AST_ROOT             — cl-cc-ast checkout
;;;;   CL_CC_TYPE_CL_WEAVE_ROOT   — cl-weave checkout

(require :asdf)

(flet ((root (env-var)
         (let ((v (uiop:getenv env-var)))
           (unless v
             (format t "~&FAIL cl-cc-type-test: ~A is not set~%" env-var)
             (finish-output)
             (sb-ext:exit :code 1))
           (truename v))))
  (asdf:initialize-source-registry
   (list :source-registry
         (list :tree (truename "."))
         (list :tree (root "CL_CC_AST_ROOT"))
         (list :tree (root "CL_CC_TYPE_CL_WEAVE_ROOT"))
         :inherit-configuration)))

(handler-case
    (asdf:load-system :cl-cc-type-test)
  (error (e)
    (format t "~&FAIL cl-cc-type-test load: ~a~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(if (funcall (find-symbol "RUN-ALL" :cl-weave)
             :reporter :spec
             :pass-with-no-tests nil)
    (progn (format t "~&RESULT: ALL PASS~%") (finish-output))
    (progn (format t "~&RESULT: FAIL~%") (finish-output) (sb-ext:exit :code 1)))
