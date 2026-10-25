;;;; t/types-hlist-test.lisp — Heterogeneous List (HList) Types Tests
;;;;
;;;; Tests for src/types-hlist.lisp (FR-1803):
;;;; make-hlist-type, hlist-head-type, hlist-tail-type, and their rejection of
;;;; non-type elements and out-of-range tails.

(in-package :cl-cc/type/hlist/test)

(it-sequential "hlist-type-family-builds-heads-tails-and-rejects-non-type-elements"
  (let* ((hlist (make-hlist-type
                 (list type-int type-string type-bool)))
         (tail (hlist-tail-type hlist))
         (last (hlist-tail-type tail)))
    (expect (type-advanced-p hlist) :to-be-truthy)
    (expect (type-advanced-feature-id hlist) :to-equal "FR-1803")
    (expect (hlist-head-type hlist) :to-be-type-equal-to type-int)
    (expect (type-advanced-p tail) :to-be-truthy)
    (expect (hlist-head-type tail) :to-be-type-equal-to type-string)
    ;; LAST wraps a single remaining element — head-type still works...
    (expect (hlist-head-type last) :to-be-type-equal-to type-bool)
    ;; ...but taking its tail would build an empty HList, which the FR-1803
    ;; semantic contract (min-args 1) rejects.
    (signals error (hlist-tail-type last)))
  (signals error (make-hlist-type (list 'not-a-type)))
  (signals error (hlist-head-type type-int))
  (signals error (hlist-tail-type type-int)))

