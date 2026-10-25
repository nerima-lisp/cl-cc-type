(in-package #:cl-cc/type/effects/test)

(defun %type-phase-make-effect-row (&rest names)
  (make-type-effect-row :effects (mapcar (lambda (n) (make-type-effect-op :name n :args nil)) names)
                         :row-var nil))

(it-each (("phase-d-effect-row-union-count io+state-merges" 2 (io)  (state))
          ("phase-d-effect-row-union-count io+pure-left"    1 (io)  ())
          ("phase-d-effect-row-union-count io+pure-right"   1 ()    (io)))
    "~A"
    (name-ignored expected-count a-names b-names)
  (declare (ignore name-ignored))
  (let* ((row-a (apply #'%type-phase-make-effect-row a-names))
         (row-b (apply #'%type-phase-make-effect-row b-names))
         (union (effect-row-union row-a row-b)))
    (expect (type-effect-row-p union) :to-be-truthy)
    (expect (length (type-effect-row-effects union)) :to-equal expected-count)))

(it-each (("phase-d-effect-row-subset smaller-of-larger"     t   (io)       (io state))
          ("phase-d-effect-row-subset larger-not-of-smaller" nil (io state) (io))
          ("phase-d-effect-row-subset pure-is-subset-of-any" t   ()         (io)))
    "~A"
    (name-ignored expected sub-names sup-names)
  (declare (ignore name-ignored))
  (let ((sub (apply #'%type-phase-make-effect-row sub-names))
        (sup (apply #'%type-phase-make-effect-row sup-names)))
    (if expected
        (expect (effect-row-subset-p sub sup) :to-be-truthy)
        (expect (effect-row-subset-p sub sup) :to-be-falsy))))
