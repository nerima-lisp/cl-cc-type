(in-package #:cl-cc/type/inference/test)

(it-each
 (("phase-a-infer-args-cases empty" nil 0)
  ("phase-a-infer-args-cases multiple" t 2))
 "~A"
 (name-ignored use-args-p expected-count)
 (declare (ignore name-ignored))
 (reset-type-vars!)
 (let* ((args
         (if use-args-p
             (list (cl-cc/parse:lower-sexp-to-ast 1)
                   (cl-cc/parse:lower-sexp-to-ast "hello"))
             '()))
        (env (type-env-empty)))
   (multiple-value-bind (types subst) (infer-args args env)
     (declare (ignore subst))
     (expect (length types) :to-equal expected-count)
     (when use-args-p
       (expect (type-equal-p type-int (first types)) :to-be-truthy)
       (expect (type-equal-p type-string (second types)) :to-be-truthy)))))

