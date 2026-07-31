;;;; t/types-extended-units-test.lisp — Units of Measure Tests
;;;;
;;;; Tests for src/types-extended-units.lisp:
;;;; measure arithmetic, unit conversion, and dimension checking.

(in-package :cl-cc-type/test)

(it-sequential "units-of-measure-perform-dimension-checking"
  (let* ((one-meter (cl-cc/type:make-measure 1 'meter))
         (hundred-centimeters (cl-cc/type:make-measure 100 'centimeter))
         (two-seconds (cl-cc/type:make-measure 2 'second))
         (sum (cl-cc/type:measure+ one-meter hundred-centimeters))
         (velocity (cl-cc/type:measure/ (cl-cc/type:make-measure 10 'meter) two-seconds)))
    (expect (cl-cc/type:measure-value sum) :to-equal 2)
    (expect (cl-cc/type:unit-compatible-p (cl-cc/type:measure-unit sum) 'meter) :to-be-truthy)
    (expect (cl-cc/type:convert-unit 100 'centimeter 'meter) :to-equal 1)
    (expect (cl-cc/type:unit-definition-dimension (cl-cc/type:measure-unit velocity))
            :to-equal '((:LENGTH . 1) (:TIME . -1)))
    (signals cl-cc/type:unit-mismatch-error
        (cl-cc/type:measure+ one-meter two-seconds))))

(it-sequential "find-unit-returns-the-registered-unit-definition"
  (let ((meter-unit (cl-cc/type:find-unit 'meter)))
    (expect (cl-cc/type:unit-definition-p meter-unit) :to-be-truthy)
    (expect (symbol-name (cl-cc/type:unit-definition-name meter-unit)) :to-equal "METER")
    (expect (cl-cc/type:unit-definition-scale meter-unit) :to-equal 1)))

(it-sequential "find-unit-signals-an-error-for-an-unregistered-unit"
  (signals error (cl-cc/type:find-unit 'furlong-per-fortnight)))

(it-sequential "unit-key-recurses-through-a-unit-definitions-own-name"
  ;; %UNIT-KEY's first COND clause (UNIT-DEFINITION-P name) is never
  ;; reached via FIND-UNIT/UNIT-DESIGNATOR-P/%RESOLVE-UNIT in this suite:
  ;; each of those already special-cases a UNIT-DEFINITION argument before
  ;; ever calling %UNIT-KEY on it. Drive it directly instead.
  (expect (cl-cc/type::%unit-key (cl-cc/type:find-unit 'meter)) :to-equal "METER"))

(it-sequential "unit-designator-p-recognizes-registered-names-and-definitions"
  (expect (cl-cc/type:unit-designator-p 'meter) :to-be-truthy)
  (expect (cl-cc/type:unit-designator-p (cl-cc/type:find-unit 'kilogram)) :to-be-truthy)
  (expect (cl-cc/type:unit-designator-p 'not-a-known-unit) :to-be-falsy))

(it-sequential "define-unit-registers-a-custom-unit-with-normalized-dimension"
  (cl-cc/type:define-unit 'league
      '((:time . 0) (:length . 1)) 201.168)
  (let ((league-unit (cl-cc/type:find-unit 'league)))
    (expect (cl-cc/type:unit-definition-dimension league-unit)
            :to-equal '((:LENGTH . 1)))
    (expect (cl-cc/type:unit-compatible-p 'league 'meter) :to-be-truthy)
    (expect (cl-cc/type:convert-unit 1 'league 'meter) :to-equal 201.168)))

(it-sequential "convert-unit-signals-error-directly-for-incompatible-dimensions"
  (signals cl-cc/type:unit-mismatch-error
      (cl-cc/type:convert-unit 1 'meter 'second)))

(it-sequential "convert-measure-converts-into-the-target-unit"
  (let* ((two-kilometers (cl-cc/type:make-measure 2 'kilometer))
         (converted (cl-cc/type:convert-measure two-kilometers 'meter)))
    (expect (cl-cc/type:measure-value converted) :to-equal 2000)
    (expect (symbol-name (cl-cc/type:unit-definition-name (cl-cc/type:measure-unit converted)))
            :to-equal "METER")))

(it-sequential "measure-minus-subtracts-values-preserving-lefts-unit"
  (let* ((five-meters (cl-cc/type:make-measure 5 'meter))
         (two-hundred-centimeters (cl-cc/type:make-measure 200 'centimeter))
         (difference (cl-cc/type:measure- five-meters two-hundred-centimeters)))
    (expect (cl-cc/type:measure-value difference) :to-equal 3)
    (expect (symbol-name (cl-cc/type:unit-definition-name (cl-cc/type:measure-unit difference)))
            :to-equal "METER")
    (signals cl-cc/type:unit-mismatch-error
        (cl-cc/type:measure- five-meters (cl-cc/type:make-measure 1 'second)))))

(it-sequential "measure-star-multiplies-values-and-derives-a-product-unit"
  (let* ((five-meters (cl-cc/type:make-measure 5 'meter))
         (three-seconds (cl-cc/type:make-measure 3 'second))
         (product (cl-cc/type:measure* five-meters three-seconds)))
    (expect (cl-cc/type:measure-value product) :to-equal 15)
    (expect (cl-cc/type:unit-definition-dimension (cl-cc/type:measure-unit product))
            :to-equal '((:LENGTH . 1) (:TIME . 1)))))

(it-sequential "unit-key-accepts-a-raw-string-designator-and-rejects-an-unsupported-shape"
  ;; %UNIT-KEY's UNIT-DEFINITION-P and SYMBOLP arms are already driven by
  ;; the pre-existing tests; its STRINGP arm and final fallback are not,
  ;; since every unit designator elsewhere in this file is a symbol or an
  ;; already-resolved unit-definition.
  (expect (cl-cc/type:unit-definition-p (cl-cc/type:find-unit "meter")) :to-be-truthy)
  (signals error
      (cl-cc/type:find-unit 42)))

(it-sequential "resolve-unit-rejects-an-unsupported-designator-shape"
  (signals error
      (cl-cc/type:unit-dimension= 42 'meter)))

(it-sequential "measure-star-cancels-dimensions-that-multiply-to-zero-exponent"
  (let* ((ten-meters (cl-cc/type:make-measure 10 'meter))
         (inverse-meters (cl-cc/type:measure/ (cl-cc/type:make-measure 1 'meter)
                                              (cl-cc/type:make-measure 1 'meter)))
         (product (cl-cc/type:measure* ten-meters inverse-meters)))
    (expect (cl-cc/type:unit-definition-dimension (cl-cc/type:measure-unit inverse-meters))
            :to-equal nil)
    (expect (cl-cc/type:measure-value product) :to-equal 10)
    (expect (cl-cc/type:unit-definition-dimension (cl-cc/type:measure-unit product))
            :to-equal '((:LENGTH . 1)))))

