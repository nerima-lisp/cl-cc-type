;;;; t/typeclass-test.lisp — Typeclass System Tests
;;;;
;;;; Tests for src/typeclass.lisp:
;;;; typeclass-def, typeclass-instance, registries, dict-env,
;;;; has-typeclass-instance-p, and check-typeclass-constraint.

(in-package #:cl-cc/type/type-classes/test)

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
    (expect (typeclass-def-superclasses td) :to-equal '(eq)))
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
  (let ((*typeclass-registry* (make-hash-table :test #'eq)))
    (let ((td (make-typeclass-def :name 'test-tc :type-params nil :methods nil)))
      (register-typeclass 'test-tc td)
      (expect (lookup-typeclass 'test-tc) :to-be td))
    (expect (lookup-typeclass 'nonexistent) :to-be-null)))

(it-sequential "typeclass-registry-rejects-noncanonical-input"
  (let ((*typeclass-registry* (make-hash-table :test #'eq)))
    (signals type-inference-error
      (register-typeclass 'bad-input '(:invalid payload)))))

(it-sequential "typeclass-default-methods-merge-into-instance"
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
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
  (let ((*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (let ((inst (register-typeclass-instance 'eq type-int '((%equal . t)))))
      (expect (typeclass-instance-p inst) :to-be-truthy)
      (expect (typeclass-instance-class-name inst) :to-be 'eq)
      (expect (lookup-typeclass-instance 'eq type-int) :to-be inst))
    (expect (lookup-typeclass-instance 'eq type-string) :to-be-null)))

(it-sequential "existing-class-instances-filters-by-class-name-and-tolerates-non-cons-keys"
  (let ((*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass-instance 'eq type-int nil)
    (register-typeclass-instance 'ord type-string nil)
    (setf (gethash 'malformed-key *typeclass-instance-registry*) 'ignored)
    (let ((eq-instances (%existing-class-instances 'eq)))
      (expect (length eq-instances) :to-equal 1)
      (expect (typeclass-instance-class-name (first eq-instances)) :to-be 'eq))))

(progn
  (it-sequential "typeclass-instance-registry-rejection-cases duplicate"
    (let ((second-type type-int))
      (declare (ignorable second-type))
      (let ((*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'eq type-int nil)
        (signals type-inference-error
          (register-typeclass-instance 'eq second-type nil)))))
  (it-sequential "typeclass-instance-registry-rejection-cases overlap"
    (let ((second-type (fresh-type-var :name "a")))
      (declare (ignorable second-type))
      (let ((*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'eq type-int nil)
        (signals type-inference-error
          (register-typeclass-instance 'eq second-type nil))))))

(it-sequential "typeclass-instance-registry-enforces-functional-dependencies"
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
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
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases numeric"
    (let ((expected t) (name 'numeric))
      (declare (ignorable expected name))
      (if expected
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases NUM"
    (let ((expected t) (name 'NUM))
      (declare (ignorable expected name))
      (if expected
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases NUMERIC"
    (let ((expected t) (name 'NUMERIC))
      (declare (ignorable expected name))
      (if expected
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases eq"
    (let ((expected nil) (name 'eq))
      (declare (ignorable expected name))
      (if expected
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases non-symbol"
    (let ((expected nil) (name 42))
      (declare (ignorable expected name))
      (if expected
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy))))
  (it-sequential "default-numeric-typeclass-p-cases nil-input"
    (let ((expected nil) (name nil))
      (declare (ignorable expected name))
      (if expected
          (expect (default-numeric-typeclass-p name) :to-be-truthy)
          (expect (default-numeric-typeclass-p name) :to-be-falsy)))))

;;; ─── has-typeclass-instance-p ──────────────────────────────────────────────

(it-sequential "has-typeclass-instance-p-false-before-true-after-registration"
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (expect (has-typeclass-instance-p 'eq type-int) :to-be-falsy)
    (register-typeclass-instance 'eq type-int nil)
    (expect (has-typeclass-instance-p 'eq type-int) :to-be-truthy)))

(it-sequential "has-typeclass-instance-p-via-superclass-chain"
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass-instance 'eq type-int nil)
    (register-typeclass 'ord (make-typeclass-def
                              :name 'ord
                              :superclasses '(eq)
                              :type-params nil
                              :methods nil))
    (expect (has-typeclass-instance-p 'ord type-int) :to-be-truthy)))

;;; ─── check-typeclass-constraint ────────────────────────────────────────────

(it-sequential "check-typeclass-constraint-behavior"
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass-instance 'eq type-int nil)
    (check-typeclass-constraint 'eq type-int       (type-env-empty))
    (check-typeclass-constraint 'eq +type-unknown+ (type-env-empty))
    (check-typeclass-constraint 'eq (fresh-type-var :name "a") (type-env-empty))
    (expect t :to-be-truthy))
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (signals type-inference-error
      (check-typeclass-constraint 'eq type-int (type-env-empty)))))

;;; ─── dict-env operations ───────────────────────────────────────────────────

(it-sequential "dict-env-operations"
  (let* ((env     (type-env-empty))
         (methods '((method-a . :impl-a)))
         (env2    (dict-env-extend 'eq type-int methods env)))
    (expect (dict-env-lookup 'eq type-int env2) :to-equal methods)
    (expect (dict-env-lookup 'eq type-int env) :to-be-null)))

;;; ─── %typeclass-instance-overlaps-p ─────────────────────────────────────────

(it-sequential "typeclass-instance-overlaps-p-var-overlaps-concrete"
  (expect (%typeclass-instance-overlaps-p
                (fresh-type-var :name "a") type-int) :to-be-truthy))

(it-sequential "typeclass-instance-overlaps-p-different-concretes-do-not-overlap"
  (expect (%typeclass-instance-overlaps-p
                 type-int type-string) :to-be-falsy))

(it-sequential "typeclass-instance-overlaps-p-same-concrete-does-not-overlap"
  (expect (%typeclass-instance-overlaps-p
                 type-int type-int) :to-be-falsy))

;;; ─── %typeclass-instance-args ────────────────────────────────────────────────

(it-sequential "typeclass-instance-args-single-type-wraps-in-list"
  (let ((args (%typeclass-instance-args type-int)))
    (expect (length args) :to-equal 1)
    (expect (first args) :to-be type-int)))

(it-sequential "typeclass-instance-args-product-unpacks-elems"
  (let* ((prod (make-type-product :elems (list type-int type-string)))
         (args (%typeclass-instance-args prod)))
    (expect (length args) :to-equal 2)
    (expect (first args) :to-be type-int)
    (expect (second args) :to-be type-string)))

;;; ─── %typeclass-name-string ────────────────────────────────────────────────

(it-sequential "typeclass-name-string-non-symbol-non-string-falls-back-to-princ"
  (expect (%typeclass-name-string 42) :to-equal "42"))

;;; ─── functional dependency edge cases ──────────────────────────────────────

(it-sequential "typeclass-instance-registry-fundep-unmatched-param-name-skips-check"
  ;; A functional-dep referencing a param name absent from TYPE-PARAMS (and
  ;; expressed with bare (non-list) car/cdr) should be silently ignored by
  ;; %typeclass-fundep-pairs / %typeclass-fundep-violation-p: from-indices
  ;; fails to resolve, so the dep never triggers a violation.
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass 'orphan-fundep-test
                        (make-typeclass-def
                         :name 'orphan-fundep-test
                         :type-params (list (fresh-type-var :name "c"))
                         :superclasses nil
                         :methods nil
                         :associated-types nil
                         :functional-deps '((missing . c))))
    (register-typeclass-instance 'orphan-fundep-test type-int nil)
    (register-typeclass-instance 'orphan-fundep-test type-string nil)
    (expect (has-typeclass-instance-p 'orphan-fundep-test type-int) :to-be-truthy)
    (expect (has-typeclass-instance-p 'orphan-fundep-test type-string) :to-be-truthy)))

(it-sequential "typeclass-instance-registry-fundep-mismatched-from-keys-no-violation"
  ;; When the "from" side of a functional dependency differs between the
  ;; existing instance and the new one, %typeclass-fundep-violation-p must
  ;; skip that dep entirely (no violation), so registration succeeds.
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass 'matched-fundep-test
                        (make-typeclass-def
                         :name 'matched-fundep-test
                         :type-params (list (fresh-type-var :name "c") (fresh-type-var :name "e"))
                         :superclasses nil
                         :methods nil
                         :associated-types nil
                         :functional-deps '(((c) . (e)))))
    (let ((first-type  (make-type-product :elems (list type-int type-string)))
          (second-type (make-type-product :elems (list type-bool type-bool))))
      (register-typeclass-instance 'matched-fundep-test first-type nil)
      (register-typeclass-instance 'matched-fundep-test second-type nil)
      (expect (lookup-typeclass-instance 'matched-fundep-test first-type) :to-be-truthy)
      (expect (lookup-typeclass-instance 'matched-fundep-test second-type) :to-be-truthy))))

(it-sequential "typeclass-instance-registry-fundep-matching-from-and-to-no-violation"
  ;; When BOTH the "from" and "to" sides of a functional dependency already
  ;; agree between the existing instance and the new one, the (unless (every
  ;; #'type-equal-p existing-to new-to) (return t)) test in
  ;; %typeclass-fundep-violation-p must take its "test is true, skip the
  ;; violation" arm -- the only other existing fundep test drives the
  ;; opposite (mismatched-to, violation-signaled) arm. A third type param
  ;; outside the dependency keeps the two instances from colliding as
  ;; duplicate registrations.
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (register-typeclass 'agreeing-fundep-test
                        (make-typeclass-def
                         :name 'agreeing-fundep-test
                         :type-params (list (fresh-type-var :name "c")
                                            (fresh-type-var :name "e")
                                            (fresh-type-var :name "f"))
                         :superclasses nil
                         :methods nil
                         :associated-types nil
                         :functional-deps '(((c) . (e)))))
    (let ((first-type  (make-type-product :elems (list type-int type-string type-bool)))
          (second-type (make-type-product :elems (list type-int type-string type-char))))
      (register-typeclass-instance 'agreeing-fundep-test first-type nil)
      (register-typeclass-instance 'agreeing-fundep-test second-type nil)
      (expect (lookup-typeclass-instance 'agreeing-fundep-test first-type) :to-be-truthy)
      (expect (lookup-typeclass-instance 'agreeing-fundep-test second-type) :to-be-truthy))))

;;; ─── register-typeclass-instance without a registered typeclass-def ───────

(it-sequential "typeclass-instance-registry-skips-fundep-check-when-class-unregistered"
  ;; When CLASS-NAME has no registered typeclass-def, TC-DEF is nil so
  ;; (typeclass-def-p tc-def) short-circuits the fundep check entirely;
  ;; only the overlap check applies. Two non-overlapping instances should
  ;; register cleanly.
  (let ((*typeclass-registry* (make-hash-table :test #'eq))
        (*typeclass-instance-registry* (make-hash-table :test #'equal)))
    (expect (lookup-typeclass 'untyped-class-test) :to-be-null)
    (register-typeclass-instance 'untyped-class-test type-int nil)
    (register-typeclass-instance 'untyped-class-test type-string nil)
    (expect (has-typeclass-instance-p 'untyped-class-test type-int) :to-be-truthy)
    (expect (has-typeclass-instance-p 'untyped-class-test type-string) :to-be-truthy)))

;;; ─── %typeclass-param-name ────────────────────────────────────────────────

(progn
  (it-sequential "typeclass-param-name-cases type-var"
    (let ((param-val nil))
      (declare (ignorable param-val))
      (let ((param (or param-val (fresh-type-var :name "TestVar"))))
        (expect (stringp (%typeclass-param-name param)) :to-be-truthy))))
  (it-sequential "typeclass-param-name-cases symbol"
    (let ((param-val 'foo))
      (declare (ignorable param-val))
      (let ((param (or param-val (fresh-type-var :name "TestVar"))))
        (expect (stringp (%typeclass-param-name param)) :to-be-truthy))))
  (it-sequential "typeclass-param-name-cases string"
    (let ((param-val "bar"))
      (declare (ignorable param-val))
      (let ((param (or param-val (fresh-type-var :name "TestVar"))))
        (expect (stringp (%typeclass-param-name param)) :to-be-truthy)))))

(in-package cl-cc/type/type-classes/test)

(progn
  (it-sequential "typeclass-instance-registration int-registered"
    (let ((query-type type-int) (expected-p t))
      (declare (ignorable query-type expected-p))
      (let ((*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'num-test type-int (list (cons 'plus #'+)))
        (if expected-p
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-truthy)
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-falsy)))))
  (it-sequential "typeclass-instance-registration string-not-present"
    (let ((query-type type-string) (expected-p nil))
      (declare (ignorable query-type expected-p))
      (let ((*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'num-test type-int (list (cons 'plus #'+)))
        (if expected-p
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-truthy)
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-falsy))))))

(before-each
  (reset-type-vars!)
  (setf *typeclass-instance-registry* (make-hash-table :test #'equal)))

(it-sequential "phase-c-dict-env-miss-wrong-class"
  ;; dict-env-lookup returns nil for a wrong class key.
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'num type-int '() env0)))
    (expect (dict-env-lookup 'ord type-int env1) :to-be-null)))

(it-sequential "phase-c-dict-env-miss-wrong-type"
  ;; dict-env-lookup returns nil for a wrong type.
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'num type-int '() env0)))
    (expect (dict-env-lookup 'num type-string env1) :to-be-null)))

(it-sequential "phase-c-dict-env-operations"
  ;; dict-env-extend stores/lookup retrieves method dict; multiple independent classes coexist.
  (let* ((methods (list (cons 'plus #'+) (cons 'zero 0)))
         (env0 (type-env-empty))
         (env1 (dict-env-extend 'num type-int methods env0))
         (found (dict-env-lookup 'num type-int env1)))
    (expect found :to-be-truthy)
    (expect (length found) :to-equal 2))
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'eq  type-int '((eq-p  . #'equal)) env0))
         (env2 (dict-env-extend 'num type-int '((plus  . #'+))     env1)))
    (expect (dict-env-lookup 'eq  type-int env2) :to-be-truthy)
    (expect (dict-env-lookup 'num type-int env2) :to-be-truthy)))
(it-sequential "solver-binary-constraint-kinds typeclass"
    (flet ((residuals (c)
             (nth-value 1 (solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-typeclass-constraint 'eq +type-unknown+)) :to-be-null)
      (expect (length (residuals (make-typeclass-constraint 'eq (fresh-type-var :name "a"))))
              :to-equal 1)))
(it-sequential "solver-typeclass-constraint-on-a-concrete-type"
    ;; The pre-existing typeclass test only ever passes +TYPE-UNKNOWN+ (a
    ;; TYPE-ERROR whose message happens to be "unknown", so it takes the
    ;; TYPE-UNKNOWN-P clause) or a free TYPE-VAR; a concrete, resolved type
    ;; reaching TYPE-ERROR-P and HAS-TYPECLASS-INSTANCE-P was untested.
    (flet ((residuals (c)
             (nth-value 1 (solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-typeclass-constraint
                           'eq (make-type-error :message "not-the-unknown-sentinel")))
              :to-be-truthy)
      (register-typeclass-instance 'solver-typeclass-test type-int nil)
      (expect (residuals (make-typeclass-constraint 'solver-typeclass-test type-int))
              :to-be-null)
      (expect (length (residuals (make-typeclass-constraint 'solver-typeclass-test type-string)))
              :to-equal 1)))
