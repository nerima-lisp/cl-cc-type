;;;; run-tests.lisp — load "cl-cc-type/test" and run the cl-weave suite.
;;;;
;;;; Bootstrap script: point ASDF's source registry at this checkout, then let
;;;; the inherited configuration resolve the dependencies. cl-cc-ast and
;;;; cl-weave must already be reachable through CL_SOURCE_REGISTRY, which
;;;; flake.nix exports for `nix flake check`, `nix run .#test` and the devShell.
;;;; The script no longer takes one environment variable per sibling checkout
;;;; (CL_CC_AST_ROOT, CL_CC_TYPE_CL_WEAVE_ROOT): a private naming scheme per
;;;; repository is a second way to say what CL_SOURCE_REGISTRY already says,
;;;; and only this repository knew how to spell it.
;;;;
;;;; Usage: sbcl --script run-tests.lisp

(require :asdf)

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(asdf:initialize-source-registry
 `(:source-registry
   (:tree ,(script-directory))
   :inherit-configuration))

(handler-case
    (asdf:load-system "cl-cc-type/test")
  (error (e)
    (format t "~&FAIL cl-cc-type/test load: ~a~%" e)
    (finish-output)
    (uiop:quit 1)))

(if (uiop:symbol-call :cl-weave
                      :run-all
                      :reporter :spec
                      :pass-with-no-tests nil)
    (progn
      (format t "~&RESULT: ALL PASS~%")
      (finish-output)
      (uiop:quit 0))
    (progn
      (format t "~&RESULT: FAIL~%")
      (finish-output)
      (uiop:quit 1)))
