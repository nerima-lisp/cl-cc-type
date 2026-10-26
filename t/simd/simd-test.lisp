;;;; t/simd-test.lisp — SIMD Types Tests
;;;;
;;;; Tests for src/simd/simd.lisp (FR-2206):
;;;; data-parallel SIMD vector lane and element-type preservation.

(in-package :cl-cc/type/simd/test)

(it-sequential "concrete-simd-vectors-preserve-lanes-and-element-types"
  (let* ((left (make-simd-vector 'integer '(1 2 3)))
         (right (make-simd-vector 'integer '(4 5 6)))
         (sum (simd-add left right))
         (mapped (simd-map (lambda (value) (* value 2)) left)))
    (expect (simd-vector-lanes sum) :to-equal 3)
    (expect (simd-vector-values sum) :to-equal '(5 7 9))
    (expect (simd-vector-values mapped) :to-equal '(2 4 6))
    (signals error
        (simd-add left (make-simd-vector 'integer '(1 2))))))

(it-sequential "make-simd-vector-rejects-empty-values-and-a-mismatched-lane"
  (signals error
      (make-simd-vector 'integer '()))
  (signals error
      (make-simd-vector 'integer '(1 "two" 3))))

(it-sequential "simd-add-rejects-a-non-simd-vector-argument-and-mismatched-element-types"
  ;; %SIMD-COMPATIBLE-P's AND has four conjuncts; the pre-existing test
  ;; only ever drives the lane-count mismatch. A non-vector argument fails
  ;; the SIMD-VECTOR-P conjuncts, and same-lane-count/different-element-
  ;; type fails the final EQUAL conjunct specifically.
  (let ((int-vec (make-simd-vector 'integer '(1 2 3))))
    (signals error
        (simd-add int-vec "not-a-simd-vector"))
    (signals error
        (simd-add int-vec (make-simd-vector 'string '("a" "b" "c"))))))

(it-sequential "make-simd-type-builds-the-fr-2206-advanced-type-node"
  (let ((ty (make-simd-type type-int 4)))
    (expect (type-advanced-p ty) :to-be-truthy)
    (expect (type-advanced-name ty) :to-be (quote simd-vector))
    (expect (type-advanced-args ty) :to-equal (list type-int 4))))

