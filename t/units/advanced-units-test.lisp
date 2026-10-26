(in-package #:cl-cc/type/units/test)

(it-sequential "advanced-units-validator-rejects-an-unknown-unit"
  (signals error
      (make-type-advanced :feature-id "FR-2302"
                          :name 'units-of-measure
                          :args (list 'float)
                          :properties (list (cons :unit 'furlong)))))

