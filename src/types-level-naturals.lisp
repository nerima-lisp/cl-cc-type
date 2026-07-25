;;;; types-level-naturals.lisp — FR-1701 type-level natural numbers

(in-package :cl-cc/type)

(defun make-type-level-natural (value)
  "Construct a FR-1701 type-level natural number node."
  (unless (and (integerp value) (not (minusp value)))
    (error "Type-level natural must be a non-negative integer, got ~S" value))
  (make-type-advanced :feature-id "FR-1701" :name 'nat :args (list value)))

(defun type-level-natural-p (type)
  "Return T when TYPE is a FR-1701 natural node."
  (and (type-advanced-p type)
       (string= (type-advanced-feature-id type) "FR-1701")
       (member (type-advanced-name type) '(nat known-nat type-plus type-mul) :test #'eq)))

(defun type-level-natural-value (type)
  "Return TYPE's natural value or signal when it is not statically known."
  (cond
    ((and (integerp type) (not (minusp type))) type)
    ((and (type-level-natural-p type)
          (integerp (first (type-advanced-args type))))
     (first (type-advanced-args type)))
    (t (error "Natural value is not statically known: ~S" type))))

(defun known-nat-value (type)
  "KnownNat-style runtime extraction for FR-1701."
  (type-level-natural-value type))

(defun type-plus (left right)
  "Compute FR-1701 type-level natural addition."
  (make-type-level-natural (+ (type-level-natural-value left)
                              (type-level-natural-value right))))

(defun type-mul (left right)
  "Compute FR-1701 type-level natural multiplication."
  (make-type-level-natural (* (type-level-natural-value left)
                              (type-level-natural-value right))))

(defun make-length-indexed-vector-type (length element-type)
  "Construct (vector LENGTH ELEMENT-TYPE) as a static type constructor."
  (make-type-constructor 'vector
                         (list (make-type-level-natural length) element-type)))

(defun make-matrix-type (rows columns element-type)
  "Construct a matrix type indexed by ROWS and COLUMNS."
  (make-type-constructor 'matrix
                         (list (make-type-level-natural rows)
                               (make-type-level-natural columns)
                               element-type)))

(defun matrix-mul-type (left right)
  "Return the result type of multiplying LEFT and RIGHT matrices, or signal on shape mismatch."
  (unless (and (type-constructor-p left)
               (type-constructor-p right)
               (eq (type-constructor-name left) 'matrix)
               (eq (type-constructor-name right) 'matrix))
    (error "matrix-mul-type expects two matrix types"))
  (destructuring-bind (left-rows left-cols left-elem) (type-constructor-args left)
    (destructuring-bind (right-rows right-cols right-elem) (type-constructor-args right)
      (declare (ignore right-rows))
      (unless (= (type-level-natural-value left-cols)
                 (type-level-natural-value (first (type-constructor-args right))))
        (error "Matrix inner dimensions do not match"))
      (unless (type-equal-p left-elem right-elem)
        (error "Matrix element types do not match"))
      (make-type-constructor 'matrix (list left-rows right-cols left-elem)))))
