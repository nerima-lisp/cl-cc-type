;;;; types-hlist.lisp — FR-1803 heterogeneous list (HList) types

(in-package :cl-cc/type)

(defun make-hlist-type (types)
  "Construct a FR-1803 HList type."
  (unless (every (lambda (type) (typep type 'type-node)) types)
    (error "HList elements must be type nodes: ~S" types))
  (make-type-advanced :feature-id "FR-1803" :name 'hlist :args types))

(defun hlist-head-type (hlist-type)
  "Return the head type of HLIST-TYPE."
  (unless (and (type-advanced-p hlist-type)
               (string= (type-advanced-feature-id hlist-type) "FR-1803")
               (type-advanced-args hlist-type))
    (error "Expected non-empty HList type, got ~S" hlist-type))
  (first (type-advanced-args hlist-type)))

(defun hlist-tail-type (hlist-type)
  "Return the HList tail type of HLIST-TYPE."
  (unless (and (type-advanced-p hlist-type)
               (string= (type-advanced-feature-id hlist-type) "FR-1803")
               (type-advanced-args hlist-type))
    (error "Expected non-empty HList type, got ~S" hlist-type))
  (make-hlist-type (rest (type-advanced-args hlist-type))))
