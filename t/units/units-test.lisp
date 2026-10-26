;;;; t/types-extended-units-test.lisp — Units of Measure Tests
;;;;
;;;; Tests for src/units/types-extended-units.lisp:
;;;; measure arithmetic, unit conversion, and dimension checking.

(in-package #:cl-cc/type/units/test)

(it-sequential "units-of-measure-perform-dimension-checking"
  (let* ((one-meter (make-measure 1 'meter))
         (hundred-centimeters (make-measure 100 'centimeter))
         (two-seconds (make-measure 2 'second))
         (sum (measure+ one-meter hundred-centimeters))
         (velocity (measure/ (make-measure 10 'meter) two-seconds)))
    (expect (measure-value sum) :to-equal 2)
    (expect (unit-compatible-p (measure-unit sum) 'meter) :to-be-truthy)
    (expect (convert-unit 100 'centimeter 'meter) :to-equal 1)
    (expect (unit-definition-dimension (measure-unit velocity))
            :to-equal '((:LENGTH . 1) (:TIME . -1)))
    (signals unit-mismatch-error
        (measure+ one-meter two-seconds))))

(it-sequential "find-unit-returns-the-registered-unit-definition"
  (let ((meter-unit (find-unit 'meter)))
    (expect (unit-definition-p meter-unit) :to-be-truthy)
    (expect (symbol-name (unit-definition-name meter-unit)) :to-equal "METER")
    (expect (unit-definition-scale meter-unit) :to-equal 1)))

(it-sequential "find-unit-signals-an-error-for-an-unregistered-unit"
  (signals error (find-unit 'furlong-per-fortnight)))

(it-sequential "unit-key-recurses-through-a-unit-definitions-own-name"
  ;; %UNIT-KEY's first COND clause (UNIT-DEFINITION-P name) is never
  ;; reached via FIND-UNIT/UNIT-DESIGNATOR-P/%RESOLVE-UNIT in this suite:
  ;; each of those already special-cases a UNIT-DEFINITION argument before
  ;; ever calling %UNIT-KEY on it. Drive it directly instead.
  (expect (funcall (internal-function "cl-cc/type/units" "%UNIT-KEY") (find-unit 'meter)) :to-equal "METER"))

(it-sequential "unit-designator-p-recognizes-registered-names-and-definitions"
  (expect (unit-designator-p 'meter) :to-be-truthy)
  (expect (unit-designator-p (find-unit 'kilogram)) :to-be-truthy)
  (expect (unit-designator-p 'not-a-known-unit) :to-be-falsy))

(it-sequential "define-unit-registers-a-custom-unit-with-normalized-dimension"
  (define-unit 'league
      '((:time . 0) (:length . 1)) 201.168)
  (let ((league-unit (find-unit 'league)))
    (expect (unit-definition-dimension league-unit)
            :to-equal '((:LENGTH . 1)))
    (expect (unit-compatible-p 'league 'meter) :to-be-truthy)
    (expect (convert-unit 1 'league 'meter) :to-equal 201.168)))

(it-sequential "convert-unit-signals-error-directly-for-incompatible-dimensions"
  (signals unit-mismatch-error
      (convert-unit 1 'meter 'second)))

(it-sequential "convert-measure-converts-into-the-target-unit"
  (let* ((two-kilometers (make-measure 2 'kilometer))
         (converted (convert-measure two-kilometers 'meter)))
    (expect (measure-value converted) :to-equal 2000)
    (expect (symbol-name (unit-definition-name (measure-unit converted)))
            :to-equal "METER")))

(it-sequential "measure-minus-subtracts-values-preserving-lefts-unit"
  (let* ((five-meters (make-measure 5 'meter))
         (two-hundred-centimeters (make-measure 200 'centimeter))
         (difference (measure- five-meters two-hundred-centimeters)))
    (expect (measure-value difference) :to-equal 3)
    (expect (symbol-name (unit-definition-name (measure-unit difference)))
            :to-equal "METER")
    (signals unit-mismatch-error
        (measure- five-meters (make-measure 1 'second)))))

(it-sequential "measure-star-multiplies-values-and-derives-a-product-unit"
  (let* ((five-meters (make-measure 5 'meter))
         (three-seconds (make-measure 3 'second))
         (product (measure* five-meters three-seconds)))
    (expect (measure-value product) :to-equal 15)
    (expect (unit-definition-dimension (measure-unit product))
            :to-equal '((:LENGTH . 1) (:TIME . 1)))))

(it-sequential "unit-key-accepts-a-raw-string-designator-and-rejects-an-unsupported-shape"
  ;; %UNIT-KEY's UNIT-DEFINITION-P and SYMBOLP arms are already driven by
  ;; the pre-existing tests; its STRINGP arm and final fallback are not,
  ;; since every unit designator elsewhere in this file is a symbol or an
  ;; already-resolved unit-definition.
  (expect (unit-definition-p (find-unit "meter")) :to-be-truthy)
  (signals error
      (find-unit 42)))

(it-sequential "resolve-unit-rejects-an-unsupported-designator-shape"
  (signals error
      (unit-dimension= 42 'meter)))

(it-sequential "measure-star-cancels-dimensions-that-multiply-to-zero-exponent"
  (let* ((ten-meters (make-measure 10 'meter))
         (inverse-meters (measure/ (make-measure 1 'meter)
                                              (make-measure 1 'meter)))
         (product (measure* ten-meters inverse-meters)))
    (expect (unit-definition-dimension (measure-unit inverse-meters))
            :to-equal nil)
    (expect (measure-value product) :to-equal 10)
    (expect (unit-definition-dimension (measure-unit product))
            :to-equal '((:LENGTH . 1)))))

