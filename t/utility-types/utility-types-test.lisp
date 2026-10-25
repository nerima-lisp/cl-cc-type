;;;; t/types-utility-test.lisp — TS-Style Utility Types Tests
;;;;
;;;; Tests for src/types-utility.lisp (FR-3303/3304):
;;;; type-level naturals/strings, record transforms, and the Writable, Readonly,
;;;; Pick, Omit, Exclude, Extract, NonNullable, ReturnType utility-type family.

(in-package :cl-cc/type/utility-types/test)

(it-sequential "types-utility-family-covers-writable-deep-readonly-pick-omit-exclude-extract"
  (let* ((record (make-type-record
                  :fields (list (cons 'name type-string)
                                (cons 'age type-int))
                  :row-var nil))
         (writable (writable-type type-int))
         (deep (deep-readonly-type record))
         (picked (pick-type record '(name)))
         (omitted (omit-type record '(name)))
         (union (make-type-union
                 (list type-int type-string type-bool)))
         (excluded (exclude-type union type-string))
         (extracted (extract-type union type-int))
         (fn (make-type-arrow (list type-int) type-string)))
    (expect (type-capability-p writable) :to-be-truthy)
    (expect (type-capability-p deep) :to-be-truthy)
    (expect (= (length (type-record-fields picked)) 1) :to-be-truthy)
    (expect (car (first (type-record-fields picked))) :to-be 'name)
    (expect (= (length (type-record-fields omitted)) 1) :to-be-truthy)
    (expect (car (first (type-record-fields omitted))) :to-be 'age)
    (expect (type-union-p excluded) :to-be-truthy)
    (expect extracted :to-be-type-equal-to type-int)
    ;; Excluding every member collapses to type-null; extracting nothing does too.
    (expect (exclude-type (make-type-union (list type-int))
                                       type-int) :to-be-type-equal-to type-null)
    ;; Non-union exclude/extract go through the plain-type branches.
    (expect (exclude-type type-int type-string) :to-be-type-equal-to type-int)
    ;; EXCLUDE-TYPE's own non-union branch only had its "not a subtype, kept
    ;; as-is" outcome tested above; a non-union UNION that IS a subtype of
    ;; EXCLUDED collapses to TYPE-NULL, the other outcome of that same IF.
    (expect (exclude-type type-int type-int) :to-be-type-equal-to type-null)
    (expect (extract-type type-int type-int) :to-be-type-equal-to type-int)
    (expect (extract-type type-int type-string) :to-be-type-equal-to type-null)
    ;; non-nullable-type: direct union and non-union paths.
    (expect (non-nullable-type
              (make-type-union (list type-null type-int))) :to-be-type-equal-to type-int)
    (expect (non-nullable-type type-int) :to-be-type-equal-to type-int)
    (expect (return-type-of fn) :to-be-type-equal-to type-string)
    (signals error (return-type-of type-int))
    (signals error (pick-type type-int '(name)))
    (signals error (omit-type type-int '(name)))))

(it-sequential "deep-readonly-type-recurses-into-a-union-not-only-a-record"
  ;; DEEP-READONLY-TYPE's COND has a dedicated TYPE-UNION-P clause; the
  ;; pre-existing test only ever drives its TYPE-RECORD-P and fallback
  ;; (plain-type) clauses.
  (let ((deep (deep-readonly-type
               (make-type-union
                (list type-int type-string)))))
    (expect (type-capability-p deep) :to-be-truthy)
    (expect (type-union-p (type-capability-base deep)) :to-be-truthy)))

(it-sequential "partial-type-and-required-type-have-a-plain-type-fallback-branch"
  ;; Both IFs' pre-existing tests only ever drove the TYPE-RECORD-P arm.
  (expect (type-union-p (partial-type type-int)) :to-be-truthy)
  (expect (required-type type-int) :to-be-type-equal-to type-int))

(it-sequential "exclude-type-collapses-to-a-single-remaining-member-not-only-none-or-many"
  ;; EXCLUDE-TYPE's own COND (distinct source forms from EXTRACT-TYPE's
  ;; identically-shaped one) had its "exactly one member survives" clause
  ;; untested: the pre-existing test only ever left 0 or 2+ members.
  (expect (exclude-type
           (make-type-union (list type-int type-string))
           type-string)
          :to-be-type-equal-to type-int))

(it-sequential "non-nullable-type-covers-the-all-null-and-multi-member-union-cases"
  ;; The pre-existing test only exercises NON-NULLABLE-TYPE's single-
  ;; remaining-member clause; its "every member was null" (collapses to
  ;; type-null) and "several non-null members remain" (stays a union)
  ;; clauses were both untested.
  (expect (non-nullable-type (make-type-union (list type-null)))
          :to-be-type-equal-to type-null)
  (expect (type-union-p
           (non-nullable-type
            (make-type-union
             (list type-null type-int type-string))))
          :to-be-truthy))

