;;;; t/typeclass-test.lisp — Typeclass System Tests
;;;;
;;;; Tests for src/typeclass.lisp:
;;;; typeclass-def, typeclass-instance, registries, dict-env,
;;;; has-typeclass-instance-p, and check-typeclass-constraint.

(in-package :cl-cc-type/test)

;;; ─── typeclass-def struct ──────────────────────────────────────────────────

(it-sequential "typeclass-def-creation"
  (let ((td (make-typeclass-def
             :name 'eq
             :type-params (list (fresh-type-var :name "a"))
             :superclasses nil
             :methods '((%equal . nil))
             :associated-types nil
             :functional-deps nil)))
    (expect (typeclass-def-p td) :to-be-truthy)
    (expect (typeclass-def-name td) :to-be 'eq)
    (expect (length (typeclass-def-type-params td)) :to-equal 1)
    (expect (length (typeclass-def-methods td)) :to-equal 1))
  (let ((td (make-typeclass-def
             :name 'ord
             :type-params (list (fresh-type-var :name "a"))
             :superclasses '(eq)
             :methods '((%compare . nil)))))
    (expect (cl-cc/type:typeclass-def-superclasses td) :to-equal '(eq)))
  (let* ((a  (fresh-type-var :name 'a))
         (tc (make-typeclass-def
              :name 'functor-test
              :type-params (list a)
              :superclasses nil
              :methods (list (cons 'fmap (make-type-arrow (list type-any) type-any)))
              :associated-types nil
              :functional-deps nil)))
    (expect (typeclass-def-p tc) :to-be-truthy)
    (expect (typeclass-def-name tc) :to-be 'functor-test)
    (expect (length (typeclass-def-type-params tc)) :to-equal 1)
    (expect (length (typeclass-def-methods tc)) :to-equal 1))
  (let* ((a  (fresh-type-var :name 'a))
         (tc (make-typeclass-def
              :name 'show-test
              :type-params (list a)
              :superclasses nil
              :methods (list (cons 'show (make-type-arrow (list a) type-string)))
              :associated-types nil
              :functional-deps nil)))
    (register-typeclass 'show-test tc)
    (let ((retrieved (lookup-typeclass 'show-test)))
      (expect retrieved :to-be-truthy)
      (expect (typeclass-def-p retrieved) :to-be-truthy)
      (expect (typeclass-def-name retrieved) :to-be 'show-test))))

;;; ─── typeclass registry ────────────────────────────────────────────────────

(it-sequential "typeclass-registry-operations"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq)))
    (let ((td (make-typeclass-def :name 'test-tc :type-params nil :methods nil)))
      (register-typeclass 'test-tc td)
      (expect (lookup-typeclass 'test-tc) :to-be td))
    (expect (lookup-typeclass 'nonexistent) :to-be-null)))

(it-sequential "typeclass-registry-rejects-noncanonical-input"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq)))
    (signals type-inference-error
      (register-typeclass 'bad-input '(:invalid payload)))))

(it-sequential "typeclass-default-methods-merge-into-instance"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq))
        (cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass 'pretty-test
                        (make-typeclass-def
                         :name 'pretty-test
                         :type-params nil
                         :methods '((show . string))
                         :defaults '((show . default-show)
                                     (eq . default-eq))))
    (let ((inst (register-typeclass-instance 'pretty-test type-int '((eq . custom-eq)))))
      (expect (cdr (assoc 'eq (typeclass-instance-methods inst))) :to-be 'custom-eq)
      (expect (cdr (assoc 'show (typeclass-instance-methods inst))) :to-be 'default-show))))


(it-sequential "typeclass-instance-registration-new"
  (register-typeclass-instance 'show-int-test type-int
                               (list (cons 'show (lambda (x) (format nil "~A" x)))))
  (let ((inst (lookup-typeclass-instance 'show-int-test type-int)))
    (expect inst :to-be-truthy)
    (expect (typeclass-instance-p inst) :to-be-truthy)
    (expect (typeclass-instance-class-name inst) :to-be 'show-int-test))
  (expect (has-typeclass-instance-p 'show-int-test type-int) :to-be-truthy)
  (expect (has-typeclass-instance-p 'show-int-test type-string) :to-be-falsy))

;;; ─── typeclass-instance registry ───────────────────────────────────────────

(it-sequential "typeclass-instance-registry-operations"
  (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (let ((inst (register-typeclass-instance 'eq type-int '((%equal . t)))))
      (expect (typeclass-instance-p inst) :to-be-truthy)
      (expect (cl-cc/type:typeclass-instance-class-name inst) :to-be 'eq)
      (expect (lookup-typeclass-instance 'eq type-int) :to-be inst))
    (expect (lookup-typeclass-instance 'eq type-string) :to-be-null)))

(progn
  (it-sequential "typeclass-instance-registry-rejection-cases duplicate"
    (let ((second-type type-int))
      (declare (ignorable second-type))
      (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'eq type-int nil)
        (signals type-inference-error
          (register-typeclass-instance 'eq second-type nil)))))
  (it-sequential "typeclass-instance-registry-rejection-cases overlap"
    (let ((second-type (fresh-type-var :name "a")))
      (declare (ignorable second-type))
      (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'eq type-int nil)
        (signals type-inference-error
          (register-typeclass-instance 'eq second-type nil))))))

(it-sequential "typeclass-instance-registry-enforces-functional-dependencies"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq))
        (cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass 'collection-test
                       (make-typeclass-def
                        :name 'collection-test
                        :type-params (list (fresh-type-var :name "c") (fresh-type-var :name "e"))
                        :superclasses nil
                        :methods nil
                        :associated-types nil
                        :functional-deps '(((c) . (e)))))
    (register-typeclass-instance 'collection-test
                                 (make-type-product :elems (list type-int type-string))
                                 nil)
    (signals type-inference-error
      (register-typeclass-instance 'collection-test
                                   (make-type-product :elems (list type-int type-bool))
                                   nil))))

;;; ─── default-numeric-typeclass-p ──────────────────────────────────────────

(progn
  (it-sequential "default-numeric-typeclass-p-cases num"
    (let ((expected t) (name 'num))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases numeric"
    (let ((expected t) (name 'numeric))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases NUM"
    (let ((expected t) (name 'NUM))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases NUMERIC"
    (let ((expected t) (name 'NUMERIC))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases eq"
    (let ((expected nil) (name 'eq))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases non-symbol"
    (let ((expected nil) (name 42))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases nil-input"
    (let ((expected nil) (name nil))
      (declare (ignorable expected name))
      (if expected
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-truthy)
          (expect (cl-cc/type::default-numeric-typeclass-p name) :to-be-falsy)))))

;;; ─── has-typeclass-instance-p ──────────────────────────────────────────────

(it-sequential "has-typeclass-instance-p-false-before-true-after-registration"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq))
        (cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (expect (has-typeclass-instance-p 'eq type-int) :to-be-falsy)
    (register-typeclass-instance 'eq type-int nil)
    (expect (has-typeclass-instance-p 'eq type-int) :to-be-truthy)))

(it-sequential "has-typeclass-instance-p-via-superclass-chain"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq))
        (cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass-instance 'eq type-int nil)
    (register-typeclass 'ord (make-typeclass-def
                              :name 'ord
                              :superclasses '(eq)
                              :type-params nil
                              :methods nil))
    (expect (has-typeclass-instance-p 'ord type-int) :to-be-truthy)))

;;; ─── check-typeclass-constraint ────────────────────────────────────────────

(it-sequential "check-typeclass-constraint-behavior"
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq))
        (cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass-instance 'eq type-int nil)
    (cl-cc/type:check-typeclass-constraint 'eq type-int       (type-env-empty))
    (cl-cc/type:check-typeclass-constraint 'eq cl-cc/type:+type-unknown+ (type-env-empty))
    (cl-cc/type:check-typeclass-constraint 'eq (fresh-type-var :name "a") (type-env-empty))
    (expect t :to-be-truthy))
  (let ((cl-cc/type:*typeclass-registry* (make-hash-table :test #'eq))
        (cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (signals type-inference-error
      (cl-cc/type:check-typeclass-constraint 'eq type-int (type-env-empty)))))

;;; ─── dict-env operations ───────────────────────────────────────────────────

(it-sequential "dict-env-operations"
  (let* ((env     (type-env-empty))
         (methods '((method-a . :impl-a)))
         (env2    (cl-cc/type:dict-env-extend 'eq type-int methods env)))
    (expect (cl-cc/type:dict-env-lookup 'eq type-int env2) :to-equal methods)
    (expect (cl-cc/type:dict-env-lookup 'eq type-int env) :to-be-null)))

;;; ─── %typeclass-instance-overlaps-p ─────────────────────────────────────────

(it-sequential "typeclass-instance-overlaps-p-var-overlaps-concrete"
  (expect (cl-cc/type::%typeclass-instance-overlaps-p
                (fresh-type-var :name "a") type-int) :to-be-truthy))

(it-sequential "typeclass-instance-overlaps-p-different-concretes-do-not-overlap"
  (expect (cl-cc/type::%typeclass-instance-overlaps-p
                 type-int type-string) :to-be-falsy))

(it-sequential "typeclass-instance-overlaps-p-same-concrete-does-not-overlap"
  (expect (cl-cc/type::%typeclass-instance-overlaps-p
                 type-int type-int) :to-be-falsy))

;;; ─── %typeclass-instance-args ────────────────────────────────────────────────

(it-sequential "typeclass-instance-args-single-type-wraps-in-list"
  (let ((args (cl-cc/type::%typeclass-instance-args type-int)))
    (expect (length args) :to-equal 1)
    (expect (first args) :to-be type-int)))

(it-sequential "typeclass-instance-args-product-unpacks-elems"
  (let* ((prod (make-type-product :elems (list type-int type-string)))
         (args (cl-cc/type::%typeclass-instance-args prod)))
    (expect (length args) :to-equal 2)
    (expect (first args) :to-be type-int)
    (expect (second args) :to-be type-string)))

;;; ─── %typeclass-param-name ────────────────────────────────────────────────

(progn
  (it-sequential "typeclass-param-name-cases type-var"
    (let ((param-val nil))
      (declare (ignorable param-val))
      (let ((param (or param-val (fresh-type-var :name "TestVar"))))
        (expect (stringp (cl-cc/type::%typeclass-param-name param)) :to-be-truthy))))
  (it-sequential "typeclass-param-name-cases symbol"
    (let ((param-val 'foo))
      (declare (ignorable param-val))
      (let ((param (or param-val (fresh-type-var :name "TestVar"))))
        (expect (stringp (cl-cc/type::%typeclass-param-name param)) :to-be-truthy))))
  (it-sequential "typeclass-param-name-cases string"
    (let ((param-val "bar"))
      (declare (ignorable param-val))
      (let ((param (or param-val (fresh-type-var :name "TestVar"))))
        (expect (stringp (cl-cc/type::%typeclass-param-name param)) :to-be-truthy)))))
