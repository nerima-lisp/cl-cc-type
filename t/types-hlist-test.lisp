;;;; t/types-hlist-test.lisp — Heterogeneous List (HList) Types Tests
;;;;
;;;; Tests for src/types-hlist.lisp (FR-1803):
;;;; make-hlist-type, hlist-head-type, hlist-tail-type, and their rejection of
;;;; non-type elements and out-of-range tails.

(in-package :cl-cc-type/test)

(it-sequential "hlist-type-family-builds-heads-tails-and-rejects-non-type-elements"
  (let* ((hlist (cl-cc/type:make-hlist-type
                 (list cl-cc/type:type-int cl-cc/type:type-string cl-cc/type:type-bool)))
         (tail (cl-cc/type:hlist-tail-type hlist))
         (last (cl-cc/type:hlist-tail-type tail)))
    (expect (cl-cc/type:type-advanced-p hlist) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id hlist) :to-equal "FR-1803")
    (expect (cl-cc/type:hlist-head-type hlist) :to-be-type-equal-to cl-cc/type:type-int)
    (expect (cl-cc/type:type-advanced-p tail) :to-be-truthy)
    (expect (cl-cc/type:hlist-head-type tail) :to-be-type-equal-to cl-cc/type:type-string)
    ;; LAST wraps a single remaining element — head-type still works...
    (expect (cl-cc/type:hlist-head-type last) :to-be-type-equal-to cl-cc/type:type-bool)
    ;; ...but taking its tail would build an empty HList, which the FR-1803
    ;; semantic contract (min-args 1) rejects.
    (signals error (cl-cc/type:hlist-tail-type last)))
  (signals error (cl-cc/type:make-hlist-type (list 'not-a-type)))
  (signals error (cl-cc/type:hlist-head-type cl-cc/type:type-int))
  (signals error (cl-cc/type:hlist-tail-type cl-cc/type:type-int)))

