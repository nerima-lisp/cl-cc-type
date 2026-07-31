;;;; t/generics-test.lisp — Datatype-Generic Programming Tests
;;;;
;;;; Tests for src/generics.lisp (FR-1602):
;;;; the generic-instance registry, structural representation, show, transform,
;;;; and query, including the unregistered-type fallback branches.

(in-package :cl-cc-type/test)

(it-sequential "concrete-generics-registry-and-structural-traversal-work"
  (let* ((table cl-cc/type:*generic-instance-registry*)
         (saved (cl-cc/type:lookup-generic-instance 'keyword)))
    (unwind-protect
        (progn
          (cl-cc/type:register-generic-instance
           'keyword
           (lambda (value)
             (cl-cc/type:make-generic-sum
              :tag :keyword
              :value (cl-cc/type:make-generic-k1 :value value :type 'keyword)))
           :show (lambda (value) (string-downcase (symbol-name value)))
           :traverse (lambda (fn value) (funcall fn value)))
          (let ((representation (cl-cc/type:generic-representation-of :TOKEN)))
            (expect (cl-cc/type:generic-sum-p representation) :to-be-truthy)
            (expect (cl-cc/type:generic-representation-valid-p representation) :to-be-truthy)
            (expect (cl-cc/type:generic-show :TOKEN) :to-equal "token"))
          (expect (cl-cc/type:generic-transform #'1+ '(1 2 3)) :to-equal '(2 3 4))
          (expect (cl-cc/type:generic-query #'evenp '(1 2 3 4)) :to-equal '(2 4)))
      (if saved
          (setf (gethash 'keyword table) saved)
          (remhash 'keyword table)))))

(it-sequential "generic-representation-of-unregistered-type-branches"
  (expect (cl-cc/type:generic-u1-p (cl-cc/type:generic-representation-of nil))
          :to-be-truthy)
  (let ((rep (cl-cc/type:generic-representation-of (cons 1 2))))
    (expect (cl-cc/type:generic-product-p rep) :to-be-truthy)
    (expect (cl-cc/type:generic-k1-p (cl-cc/type:generic-product-left rep))
            :to-be-truthy)
    (expect (cl-cc/type:generic-k1-value (cl-cc/type:generic-product-left rep))
            :to-equal 1))
  (let ((rep (cl-cc/type:generic-representation-of 42)))
    (expect (cl-cc/type:generic-k1-p rep) :to-be-truthy)
    (expect (cl-cc/type:generic-k1-value rep) :to-equal 42)))

(it-sequential "generic-representation-of-uses-a-static-non-function-representation-as-is"
  ;; The pre-existing registered-instance test above always registers a
  ;; FUNCTION representation (a builder lambda), so (FUNCTIONP
  ;; REPRESENTATION)'s false branch -- a plain, already-built
  ;; representation object -- had never been exercised.
  (let* ((table cl-cc/type:*generic-instance-registry*)
         (saved (cl-cc/type:lookup-generic-instance 'ratio)))
    (unwind-protect
        (progn
          (cl-cc/type:register-generic-instance 'ratio (cl-cc/type:make-generic-u1))
          (let ((representation (cl-cc/type:generic-representation-of 1/2)))
            (expect (cl-cc/type:generic-u1-p representation) :to-be-truthy)))
      (if saved
          (setf (gethash 'ratio table) saved)
          (remhash 'ratio table)))))

(it-sequential "generic-show-unregistered-type-branches"
  (expect (cl-cc/type:generic-show (list 1 2 3)) :to-equal "(1 2 3)")
  (expect (cl-cc/type:generic-show 42) :to-equal "42"))

(it-sequential "generic-transform-uses-registered-traverse-hook"
  (let* ((table cl-cc/type:*generic-instance-registry*)
         (saved (cl-cc/type:lookup-generic-instance 'symbol)))
    (unwind-protect
        (progn
          (cl-cc/type:register-generic-instance
           'symbol nil
           :traverse (lambda (fn value) (funcall fn (symbol-name value))))
          (expect (cl-cc/type:generic-transform #'string-downcase 'HELLO)
                  :to-equal "hello"))
      (if saved
          (setf (gethash 'symbol table) saved)
          (remhash 'symbol table)))))

(it-sequential "generic-representation-valid-p-covers-every-representation-kind"
  (expect (cl-cc/type:generic-representation-valid-p (cl-cc/type:make-generic-u1))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-k1 :value 1 :type 'fixnum))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-m1 :meta :m :representation (cl-cc/type:make-generic-u1)))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-product
            :left (cl-cc/type:make-generic-u1)
            :right (cl-cc/type:make-generic-u1)))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-product
            :left (cl-cc/type:make-generic-u1)
            :right 42))
          :to-be-falsy)
  ;; The invalid-RIGHT case above already exercises the AND's second
  ;; conjunct false; LEFT's own false branch (the AND's first conjunct)
  ;; had never been driven, since it always short-circuits before RIGHT
  ;; is even checked.
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-product
            :left 42
            :right (cl-cc/type:make-generic-u1)))
          :to-be-falsy)
  (expect (cl-cc/type:generic-representation-valid-p 42) :to-be-falsy))

