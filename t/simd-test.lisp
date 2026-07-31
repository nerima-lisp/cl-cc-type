;;;; t/simd-test.lisp — SIMD Types Tests
;;;;
;;;; Tests for src/simd.lisp (FR-2206):
;;;; data-parallel SIMD vector lane and element-type preservation.

(in-package :cl-cc-type/test)

(it-sequential "concrete-simd-vectors-preserve-lanes-and-element-types"
  (let* ((left (cl-cc/type:make-simd-vector 'integer '(1 2 3)))
         (right (cl-cc/type:make-simd-vector 'integer '(4 5 6)))
         (sum (cl-cc/type:simd-add left right))
         (mapped (cl-cc/type:simd-map (lambda (value) (* value 2)) left)))
    (expect (cl-cc/type:simd-vector-lanes sum) :to-equal 3)
    (expect (cl-cc/type:simd-vector-values sum) :to-equal '(5 7 9))
    (expect (cl-cc/type:simd-vector-values mapped) :to-equal '(2 4 6))
    (signals error
        (cl-cc/type:simd-add left (cl-cc/type:make-simd-vector 'integer '(1 2))))))

(it-sequential "make-simd-vector-rejects-empty-values-and-a-mismatched-lane"
  (signals error
      (cl-cc/type:make-simd-vector 'integer '()))
  (signals error
      (cl-cc/type:make-simd-vector 'integer '(1 "two" 3))))

(it-sequential "simd-add-rejects-a-non-simd-vector-argument-and-mismatched-element-types"
  ;; %SIMD-COMPATIBLE-P's AND has four conjuncts; the pre-existing test
  ;; only ever drives the lane-count mismatch. A non-vector argument fails
  ;; the SIMD-VECTOR-P conjuncts, and same-lane-count/different-element-
  ;; type fails the final EQUAL conjunct specifically.
  (let ((int-vec (cl-cc/type:make-simd-vector 'integer '(1 2 3))))
    (signals error
        (cl-cc/type:simd-add int-vec "not-a-simd-vector"))
    (signals error
        (cl-cc/type:simd-add int-vec (cl-cc/type:make-simd-vector 'string '("a" "b" "c"))))))

(it-sequential "make-simd-type-builds-the-fr-2206-advanced-type-node"
  (let ((ty (cl-cc/type:make-simd-type cl-cc/type:type-int 4)))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::simd-vector)
    (expect (cl-cc/type:type-advanced-args ty) :to-equal (list cl-cc/type:type-int 4))))

