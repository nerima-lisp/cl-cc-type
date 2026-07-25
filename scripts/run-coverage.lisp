;;;; run-coverage.lisp — load :cl-cc-type-test with SB-COVER instrumentation
;;;; active and run the cl-weave suite under :coverage t.
;;;;
;;;; sb-cover only measures forms compiled while its STORE-COVERAGE-DATA
;;;; optimize policy is proclaimed, so :cl-cc-type must be force-recompiled
;;;; here rather than reusing scripts/run-tests.lisp's cached FASLs — mirrors
;;;; cl-weave's own CLI (cli-execution.lisp prepare-coverage-compilation).
;;;;
;;;;   CL_CC_AST_ROOT             — cl-cc-ast checkout
;;;;   CL_CC_TYPE_CL_WEAVE_ROOT   — cl-weave checkout

;; Must run before ASDF's source registry sees a custom :tree entry — once
;; that's active, (require :sb-cover) inside cl-weave's own coverage check
;; routes through ASDF's contrib-loading path and misfires with a spurious
;; "system sb-cover is out of date" condition.
(require :sb-cover)
(require :asdf)

(flet ((root (env-var)
         (let ((v (uiop:getenv env-var)))
           (unless v
             (format t "~&FAIL cl-cc-type-coverage: ~A is not set~%" env-var)
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
    (asdf:load-system :cl-weave)
  (error (e)
    (format t "~&FAIL cl-cc-type-coverage load cl-weave: ~a~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(unless (funcall (find-symbol "COVERAGE-SUPPORT-AVAILABLE-P" :cl-weave))
  (format t "~&FAIL cl-cc-type-coverage: SB-COVER is not available on this SBCL~%")
  (finish-output)
  (sb-ext:exit :code 1))

(let ((policy (find-symbol "STORE-COVERAGE-DATA" "SB-COVER")))
  (proclaim `(optimize (,policy 3))))

(handler-case
    (progn
      (asdf:load-system :cl-cc-type :force t)
      (asdf:load-system :cl-cc-type-test))
  (error (e)
    (format t "~&FAIL cl-cc-type-coverage load: ~a~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(ensure-directories-exist "coverage/report/")

(if (funcall (find-symbol "RUN-ALL" :cl-weave)
             :reporter :spec
             :pass-with-no-tests nil
             :coverage t
             :coverage-output "coverage/cl-cc-type.coverage"
             :coverage-report-directory "coverage/report/"
             :coverage-include-pathnames
             (list (asdf:system-relative-pathname :cl-cc-type "src/")))
    (progn (format t "~&RESULT: ALL PASS (coverage report: coverage/report/index.html)~%")
           (finish-output))
    (progn (format t "~&RESULT: FAIL~%") (finish-output) (sb-ext:exit :code 1)))
