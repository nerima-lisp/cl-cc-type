(in-package #:cl-cc/type/quantities/test)

(it-property "normalize-multiplicity is idempotent"
    ((value (gen-member '(0 1 :omega :zero :one :ω omega unrestricted))))
  (let ((normalized (normalize-multiplicity value)))
    (expect (normalize-multiplicity normalized) :to-be normalized)))

(it-property "multiplicity* is commutative over the QTT semiring"
    ((left (gen-member '(0 1 :omega)))
     (right (gen-member '(0 1 :omega))))
  (expect (multiplicity* left right) :to-be (multiplicity* right left)))

(it-property "multiplicity+ is commutative over the QTT semiring"
    ((left (gen-member '(0 1 :omega)))
     (right (gen-member '(0 1 :omega))))
  (expect (multiplicity+ left right) :to-be (multiplicity+ right left)))

(it-sequential "advanced-validate-qtt-fr-3401-accepts-a-valid-multiplicity-designator"
  (let ((node (parse-type-specifier '(qtt :one integer))))
    (expect (type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validators-now-use-concrete-semantic-modules"
  (signals error
      (parse-type-specifier '(advanced fr-3401 2 fixnum :evidence (proof impossible)))))

(it-sequential "printer-wrapper-type-annotations linear"
  (expect (search "1" (type-to-string (make-type-linear :base type-int :grade :one)))
          :to-be-truthy)
  (expect (search "FIXNUM" (type-to-string (make-type-linear :base type-int :grade :one)))
          :to-be-truthy))

(it-sequential "printer-arrow-mult-table zero"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :mult :zero))
            :to-match-inline-snapshot "\"FIXNUM -0-> STRING\""))

(it-sequential "printer-arrow-mult-table one"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :mult :one))
            :to-match-inline-snapshot "\"FIXNUM -1-> STRING\""))

(it-sequential "printer-arrow-mult-table omega"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :mult :omega))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\""))

(it-sequential "printer-arrow-mult-table signals-for-an-unknown-multiplicity"
    ;; TYPE-ARROW's MULT slot carries no :TYPE restriction (unlike, e.g.,
    ;; TYPE-ADVANCED's NAME), so %ARROW-STRING's own OR/ERROR fallback --
    ;; untested by the three known-good keywords above -- is genuinely
    ;; reachable via a hand-built arrow.
    (signals error
        (type-to-string (make-type-arrow (list type-int) type-string :mult :bogus))))
