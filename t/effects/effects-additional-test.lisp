(in-package #:cl-cc/type/effects/test)

(it-sequential "printer-effect-rows-and-ops"
  (expect (type-to-string +pure-effect-row+) :to-equal "{}")
  (expect (type-to-string +io-effect-row+) :to-match-inline-snapshot "\"{IO}\"")
  (let* ((rv (fresh-type-var :name "e"))
         (er (make-type-effect-row :effects nil :row-var rv)))
    (expect (SEARCH "|" (type-to-string er)) :to-be-truthy))
  (expect (type-to-string (make-type-effect-op :name 'state :args (list type-int)))
          :to-match-inline-snapshot "\"(STATE FIXNUM)\"")
  (let* ((rv  (fresh-type-var :name 'epsilon))
         (row (make-type-effect-row
               :effects (list (make-type-effect-op :name 'io))
               :row-var rv))
         (s (type-to-string row)))
    (expect (SEARCH "IO" (string-upcase s)) :to-be-truthy)
    (expect (SEARCH "|" s) :to-be-truthy)))

(it-sequential "printer-handler-uses-bracket-notation"
  (let ((eff (make-type-effect-op :name 'io :args nil)))
    (expect (type-to-string
             (make-type-handler :effect eff :input type-int :output type-string))
            :to-match-inline-snapshot "\"[IO => FIXNUM / STRING]\"")))

(progn)

(progn
  (it-sequential "effect-row-to-string pure"
    (let ((row +pure-effect-row+) (expected "{}") (substr-p nil))
      (declare (ignorable row expected substr-p))
      (let ((s (type-to-string row)))
        (if substr-p
            (expect (SEARCH expected (string-upcase s)) :to-be-truthy)
            (expect s :to-equal expected)))))
  (it-sequential "effect-row-to-string io"
    (let ((row +io-effect-row+) (expected "IO") (substr-p t))
      (declare (ignorable row expected substr-p))
      (let ((s (type-to-string row)))
        (if substr-p
            (expect (SEARCH expected (string-upcase s)) :to-be-truthy)
            (expect s :to-equal expected))))))

(progn
  (it-sequential "effect-row-singleton-cases pure"
    (let ((row +pure-effect-row+) (expected-count 0) (expected-name nil))
      (declare (ignorable row expected-count expected-name))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (length (type-effect-row-effects row)) :to-equal expected-count)
      (when expected-name
        (expect (symbol-name (type-effect-op-name (first (type-effect-row-effects row))))
                :to-equal expected-name))))
  (it-sequential "effect-row-singleton-cases io"
    (let ((row +io-effect-row+) (expected-count 1) (expected-name "IO"))
      (declare (ignorable row expected-count expected-name))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (length (type-effect-row-effects row)) :to-equal expected-count)
      (when expected-name
        (expect (symbol-name (type-effect-op-name (first (type-effect-row-effects row))))
                :to-equal expected-name))))
  (it-sequential "effect-row-singleton-cases custom"
    (let ((row (make-type-effect-row
                :effects (list (make-type-effect-op :name 'state :args nil)
                                (make-type-effect-op :name 'error :args nil))
                :row-var nil))
          (expected-count 2) (expected-name nil))
      (declare (ignorable row expected-count expected-name))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (length (type-effect-row-effects row)) :to-equal expected-count)
      (when expected-name
        (expect (symbol-name (type-effect-op-name (first (type-effect-row-effects row))))
                :to-equal expected-name)))))

