;;;; tests/package.lisp — cl-cc-type test package + cl-weave compatibility shim.
;;;;
;;;; The cl-cc-type suite was written against the monorepo's deftest /
;;;; deftest-each / assert-* macros. Rather than rewrite 500+ cases by hand,
;;;; this shim re-expresses those forms on top of cl-weave's it-sequential /
;;;; expect, so every test runs on cl-weave unchanged apart from its
;;;; in-package form. Domain helpers that tests define locally (e.g.
;;;; assert-inference-boolean-case) build on the generic asserts below.

(defpackage :cl-cc-type/test
  (:use :cl :cl-weave :cl-cc/type :cl-cc/ast)
  (:shadowing-import-from :cl-weave #:describe)
  ;; cl-cc/type defines its own compiler-domain names that shadow CL
  ;; (subtypep, type-error, upgraded-*) and cl-weave (measure, capability);
  ;; prefer the cl-cc/type versions — that is what the type tests use.
  (:shadowing-import-from :cl-cc/type
   #:type-error #:subtypep
   #:upgraded-array-element-type #:upgraded-complex-part-type
   #:measure #:capability)
  (:export #:deftest #:deftest-each #:in-suite #:defsuite #:defbefore
           #:assert-true #:assert-false #:assert-eq #:assert-eql
           #:assert-= #:assert-equal #:assert-equalp #:assert-null
           #:assert-string= #:assert-type #:assert-type-equal
           #:assert-unifies #:assert-not-unifies #:assert-signals))

(in-package :cl-cc-type/test)

;;; ── test definition shims ────────────────────────────────────────────────

(defun %test-name (designator)
  (if (stringp designator) designator (string-downcase (string designator))))

(defmacro deftest (name &body body)
  "Monorepo deftest -> a single cl-weave sequential test. A leading string
body form is treated as the (dropped) docstring."
  (when (and (stringp (first body)) (rest body))
    (setf body (rest body)))
  `(it-sequential ,(%test-name name) ,@body))

(defmacro deftest-each (base-name &body args)
  "Monorepo deftest-each -> one cl-weave test per case.
Syntax: (deftest-each name [docstring] :cases ((label val ...) ...) (var ...) body...)."
  (when (stringp (first args))
    (setf args (rest args)))
  (let* ((cases-pos (position :cases args))
         (cases (nth (1+ cases-pos) args))
         (tail  (nthcdr (+ 2 cases-pos) args))
         (vars  (first tail))
         (body  (rest tail)))
    `(progn
       ,@(loop for case in cases
               for label = (first case)
               for vals  = (rest case)
               collect `(it-sequential ,(format nil "~A ~A" (%test-name base-name) label)
                          (destructuring-bind ,vars (list ,@vals)
                            (declare (ignorable ,@vars))
                            ,@body))))))

(defmacro in-suite (&rest ignored)
  "Suites are a monorepo concept; cl-weave groups by describe. No-op here."
  (declare (ignore ignored))
  nil)

(defmacro defsuite (name &rest options)
  "Monorepo suite declaration; no-op on cl-weave (tests run flat)."
  (declare (ignore name options))
  nil)

(defmacro defbefore (kind suites &body body)
  "Monorepo suite-scoped setup hook -> cl-weave root before-each/before-all.
The suite argument is ignored; the hook applies to the flat test set."
  (declare (ignore suites))
  (ecase kind
    (:each `(before-each ,@body))
    (:all  `(before-all ,@body))))

;;; ── assertion shims (map onto cl-weave expect) ───────────────────────────

(defmacro assert-true (form &rest _)       (declare (ignore _)) `(expect ,form :to-be-truthy))
(defmacro assert-false (form &rest _)      (declare (ignore _)) `(expect ,form :to-be-falsy))
(defmacro assert-null (form &rest _)       (declare (ignore _)) `(expect ,form :to-be-null))
(defmacro assert-eq (expected actual &rest _)     (declare (ignore _)) `(expect ,actual :to-be ,expected))
(defmacro assert-eql (expected actual &rest _)    (declare (ignore _)) `(expect ,actual :to-be ,expected))
(defmacro assert-= (expected actual &rest _)      (declare (ignore _)) `(expect ,actual :to-equal ,expected))
(defmacro assert-equal (expected actual &rest _)  (declare (ignore _)) `(expect ,actual :to-equal ,expected))
(defmacro assert-equalp (expected actual &rest _) (declare (ignore _)) `(expect ,actual :to-equalp ,expected))
(defmacro assert-string= (expected actual &rest _) (declare (ignore _)) `(expect ,actual :to-equal ,expected))

(defmacro assert-type (type-name object &rest _)
  (declare (ignore _))
  `(expect (typep ,object ',type-name) :to-be-truthy))

(defmacro assert-type-equal (expected actual &rest _)
  (declare (ignore _))
  `(expect (cl-cc/type:type-equal-p ,expected ,actual) :to-be-truthy))

(defmacro assert-unifies (t1 t2 &rest _)
  (declare (ignore _))
  `(expect (nth-value 1 (cl-cc/type:type-unify ,t1 ,t2)) :to-be-truthy))

(defmacro assert-not-unifies (t1 t2 &rest _)
  (declare (ignore _))
  `(expect (nth-value 1 (cl-cc/type:type-unify ,t1 ,t2)) :to-be-falsy))

(defmacro assert-signals (condition &body body)
  (let ((flag (gensym "SIGNALED")))
    `(let ((,flag nil))
       (handler-case (progn ,@body)
         (,condition () (setf ,flag t)))
       (expect ,flag :to-be-truthy))))
