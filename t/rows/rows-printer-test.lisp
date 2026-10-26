(in-package #:cl-cc/type/rows/test)

(it-sequential "printer-row-fields-empty-variant-closed"
  (expect (type-to-string (make-type-variant :cases nil :row-var nil))
          :to-match-inline-snapshot "\"<>\""))

(it-sequential "printer-row-fields-empty-record-open"
  (let ((rv (fresh-type-var :name "rho")))
    (expect (type-to-string (make-type-record :fields nil :row-var rv))
            :to-match-inline-snapshot "\"{ | ?rho}\"")))

(it-sequential "printer-row-fields-empty-record-closed"
  (expect (type-to-string (make-type-record :fields nil :row-var nil))
          :to-match-inline-snapshot "\"{}\""))

(progn
  (it-sequential "printer-record-cases closed"
    (expect (type-to-string
             (make-type-record :fields (list (cons 'x type-int) (cons 'y type-bool))
                                :row-var nil))
            :to-match-inline-snapshot "\"{X: FIXNUM, Y: BOOLEAN}\""))
  (it-sequential "printer-record-cases open"
    (let* ((rv (fresh-type-var :name "rho"))
           (r (make-type-record :fields (list (cons 'x type-int)) :row-var rv))
           (s (type-to-string r)))
      (expect (search "|" s) :to-be-truthy)
      (expect (search "{X: FIXNUM |" s) :to-be-truthy))))

(it-sequential "printer-container-type-delimiters variant"
    (expect (type-to-string
             (make-type-variant
              :cases (list (cons 'some type-int) (cons 'none type-null))
              :row-var nil))
            :to-match-inline-snapshot "\"<SOME: FIXNUM, NONE: NULL>\""))
