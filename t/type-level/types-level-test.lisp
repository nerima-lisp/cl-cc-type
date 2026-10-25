;;;; t/types-utility-test.lisp — TS-Style Utility Types Tests
;;;;
;;;; Tests for src/types-utility.lisp (FR-3303/3304):
;;;; type-level naturals/strings, record transforms, and the Writable, Readonly,
;;;; Pick, Omit, Exclude, Extract, NonNullable, ReturnType utility-type family.

(in-package :cl-cc/type/type-level/test)

(it-sequential "type-level-constructors-cover-static-nats-strings-vectors-and-matrices"
  (let* ((nat-two (make-type-level-natural 2))
         (nat-five (type-plus nat-two 3))
         (template (template-literal-type
                    "user-" (make-type-level-string "id")))
         (matrix-product (matrix-mul-type
                          (make-matrix-type 2 3 type-int)
                          (make-matrix-type 3 4 type-int))))
    (expect (type-level-natural-value nat-five) :to-equal 5)
    (expect (known-nat-value nat-five) :to-equal 5)
    (expect (type-level-string-value template) :to-equal "user-id")
    (let ((vec (make-length-indexed-vector-type 3 type-int)))
      (expect (type-constructor-p vec) :to-be-truthy)
      (expect (type-constructor-name vec) :to-be 'vector)
      (expect (type-level-natural-value (first (type-constructor-args vec)))
              :to-equal 3))
    (let ((args (type-constructor-args matrix-product)))
      (expect (type-level-natural-value (first args)) :to-equal 2)
      (expect (type-level-natural-value (second args)) :to-equal 4)
      (expect type-int :to-be-type-equal-to (third args)))))

(it-sequential "make-type-level-natural-rejects-non-natural-values"
  (signals error
      (make-type-level-natural -1))
  (signals error
      (make-type-level-natural "3")))

(it-sequential "type-mul-computes-fr-1701-type-level-natural-multiplication"
  ;; TYPE-PLUS is exercised above via NAT-FIVE; its sibling TYPE-MUL had no
  ;; test anywhere.
  (let ((product (type-mul (make-type-level-natural 3)
                                       (make-type-level-natural 4))))
    (expect (type-level-natural-value product) :to-equal 12)))

(it-sequential "type-level-natural-p-is-falsy-for-unrelated-types"
  (expect (type-level-natural-p (make-type-level-natural 3))
          :to-be-truthy)
  (expect (type-level-natural-p type-int) :to-be-falsy))

(it-sequential "type-level-natural-value-accepts-a-raw-non-negative-integer-directly"
  ;; Every pre-existing call passes a wrapped FR-1701 nat node, so the
  ;; COND's first clause, (AND (INTEGERP type) (NOT (MINUSP type))), had
  ;; only ever been observed false (via the wrapped-node calls) or reached
  ;; via a non-integer (also false) -- never its own true outcome.
  (expect (type-level-natural-value 5) :to-equal 5))

(it-sequential "type-level-natural-value-signals-when-the-value-is-not-statically-known"
  ;; Neither a raw non-negative integer nor a proper FR-1701 nat node with
  ;; a known integer arg: the COND's final ERROR clause was never reached.
  (signals error
      (type-level-natural-value "not-a-natural"))
  (signals error
      (type-level-natural-value type-int)))

(it-sequential "type-level-natural-value-signals-for-a-raw-negative-integer"
  ;; Every pre-existing call site passes either a non-negative raw integer
  ;; or a non-integer, so the first COND clause's (MINUSP type) conjunct
  ;; had only ever been observed false -- never its own true outcome. A
  ;; raw negative integer is INTEGERP but MINUSP, so it falls through to
  ;; the final ERROR clause rather than the wrapped-node clause (which
  ;; also fails, since a raw integer is never TYPE-LEVEL-NATURAL-P).
  (signals error
      (type-level-natural-value -5)))

(it-sequential "make-type-level-string-rejects-a-non-string-value"
  (signals error
      (make-type-level-string :not-a-string)))

(it-sequential "type-level-string-p-is-falsy-for-unrelated-types"
  (expect (type-level-string-p (make-type-level-string "id"))
          :to-be-truthy)
  (expect (type-level-string-p type-string) :to-be-falsy))

(it-sequential "type-level-string-value-accepts-a-raw-string-and-signals-otherwise"
  ;; TEMPLATE-LITERAL-TYPE never calls TYPE-LEVEL-STRING-VALUE on a raw
  ;; string part (it takes the PRINC-TO-STRING branch instead), so this
  ;; COND's first clause -- and its final ERROR clause -- were untested.
  (expect (type-level-string-value "already-a-string") :to-equal "already-a-string")
  (signals error
      (type-level-string-value 42)))

(it-sequential "get-field-type-rejects-a-non-record-type-and-an-unknown-field"
  (let ((record (make-type-record
                 :fields (list (cons 'name type-string))
                 :row-var nil)))
    (signals error
        (get-field-type 'name type-string))
    (signals error
        (get-field-type 'missing-field record))))

(it-sequential "get-field-type-matches-a-non-symbol-field-name-designator-case-insensitively"
  ;; %FIELD-NAME= falls back to PRINC-TO-STRING when its argument is not a
  ;; symbol; the pre-existing tests only ever search with a symbol.
  (let ((record (make-type-record
                 :fields (list (cons 'name type-string))
                 :row-var nil)))
    (expect type-string
            :to-be-type-equal-to (get-field-type "name" record))))

(it-sequential "get-field-type-matches-when-the-records-own-field-key-is-a-non-symbol"
  ;; The case above only ever drives %FIELD-NAME='s search-argument (LEFT)
  ;; through the non-symbol PRINC-TO-STRING fallback; every record's own
  ;; field key (RIGHT, matched via CAR) is conventionally a symbol, so that
  ;; side of the same fallback had never fired.
  (let ((record (make-type-record
                 :fields (list (cons "name" type-string))
                 :row-var nil)))
    (expect type-string
            :to-be-type-equal-to (get-field-type 'name record))))

(it-sequential "matrix-mul-type-rejects-non-matrix-arguments"
  (signals error
      (matrix-mul-type
       type-int
       (make-matrix-type 3 4 type-int)))
  ;; The case above only drives LEFT through the non-matrix path; the
  ;; guard's own (TYPE-CONSTRUCTOR-P right) conjunct had never been
  ;; observed false, since every other call passes a valid matrix RIGHT.
  (signals error
      (matrix-mul-type
       (make-matrix-type 2 3 type-int)
       type-int)))

(it-sequential "matrix-mul-type-rejects-mismatched-inner-dimensions"
  (signals error
      (matrix-mul-type
       (make-matrix-type 2 3 type-int)
       (make-matrix-type 4 4 type-int))))

(it-sequential "matrix-mul-type-rejects-mismatched-element-types"
  (signals error
      (matrix-mul-type
       (make-matrix-type 2 3 type-int)
       (make-matrix-type 3 4 type-string))))

