;;;; t/types-extended-advanced-meta-test.lisp — Advanced feature/head registry tests
;;;;
;;;; Tests for src/types-extended-advanced-meta.lisp. register-type-advanced-feature
;;;; and register-type-advanced-head also run once at load time (from
;;;; %initialize-type-advanced-feature-registry, seeding every real FR id), so these
;;;; tests register additional test-only entries under a "FR-9999*" id rather than
;;;; re-registering real ids, to exercise the same code paths without disturbing the
;;;; production registry state other test files rely on.

(in-package :cl-cc/type/advanced-metadata/test)

(it-sequential "type-advanced-feature-constructor-and-accessors"
  (let ((feature (make-type-advanced-feature
                  :id "fr-9999-meta-test"
                  :title "Meta Test Feature"
                  :heads '(seed-head))))
    (expect (type-advanced-feature-p feature) :to-be-truthy)
    (expect (type-advanced-feature-fr-id feature) :to-equal "FR-9999-META-TEST")
    (expect (type-advanced-feature-title feature) :to-equal "Meta Test Feature")
    (expect (type-advanced-feature-heads feature) :to-equal '(seed-head))))

(it-sequential "register-and-lookup-type-advanced-feature-round-trips"
  (register-type-advanced-feature
   (make-type-advanced-feature :id 'fr-9999-round-trip :title "Round Trip"))
  (let ((found (lookup-type-advanced-feature "fr-9999-round-trip")))
    (expect (type-advanced-feature-p found) :to-be-truthy)
    (expect (type-advanced-feature-fr-id found) :to-equal "FR-9999-ROUND-TRIP")
    (expect (type-advanced-feature-title found) :to-equal "Round Trip"))
  (expect (member "FR-9999-ROUND-TRIP" (list-type-advanced-feature-ids)
                  :test #'string=)
          :to-be-truthy))

(it-sequential "lookup-type-advanced-feature-unregistered-id-returns-nil"
  (expect (lookup-type-advanced-feature "fr-9999-never-registered") :to-be-null))

(it-sequential "register-type-advanced-head-unknown-feature-id-signals-error"
  (signals error
      (register-type-advanced-head 'fr-9999-orphan-head "fr-9999-does-not-exist")))

(it-sequential "register-type-advanced-head-adds-head-to-feature-heads"
  (register-type-advanced-feature
   (make-type-advanced-feature :id 'fr-9999-head-owner :title "Head Owner"))
  (register-type-advanced-head 'fr-9999-new-head 'fr-9999-head-owner)
  (expect (type-advanced-feature-id-for-head 'fr-9999-new-head)
          :to-equal "FR-9999-HEAD-OWNER")
  (expect (type-advanced-head-p 'fr-9999-new-head) :to-be-truthy)
  (expect (member "FR-9999-NEW-HEAD"
                  (type-advanced-feature-heads
                   (lookup-type-advanced-feature 'fr-9999-head-owner))
                  :test #'string=)
          :to-be-truthy))

(it-sequential "register-type-advanced-head-accepts-a-raw-string-head"
  ;; The pre-existing tests only ever pass a symbol HEAD; REGISTER-TYPE-
  ;; ADVANCED-HEAD's own (IF (SYMBOLP head) (SYMBOL-NAME head) head)
  ;; branch for an already-string head was never taken.
  (register-type-advanced-feature
   (make-type-advanced-feature :id 'fr-9999-string-head-owner :title "String Head Owner"))
  (register-type-advanced-head "fr-9999-string-head" 'fr-9999-string-head-owner)
  (expect (type-advanced-feature-id-for-head "fr-9999-string-head")
          :to-equal "FR-9999-STRING-HEAD-OWNER"))

(it-sequential "type-advanced-head-p-accepts-a-raw-string-head"
  ;; Mirrors the string-head coverage above, but for TYPE-ADVANCED-HEAD-P's
  ;; own (IF (SYMBOLP head) ...) branch specifically -- the pre-existing
  ;; string-argument test for this function's sibling,
  ;; TYPE-ADVANCED-FEATURE-ID-FOR-HEAD, does not also exercise this one.
  (expect (type-advanced-head-p "qtt") :to-be-truthy))

(it-sequential "type-advanced-feature-id-for-head-is-nil-for-a-non-symbol-non-string-head"
  ;; TYPE-ADVANCED-HEAD-P already has a non-symbol/non-string case (42);
  ;; TYPE-ADVANCED-FEATURE-ID-FOR-HEAD's own (OR (SYMBOLP head) (STRINGP
  ;; head)) guard needs its own, since falling through to the shared
  ;; registry lookup would otherwise never be skipped for this function.
  (expect (type-advanced-feature-id-for-head 42) :to-be-null))

(it-sequential "advanced-feature-registry-listing-and-head-lookup-helpers"
  (let ((ids (list-type-advanced-feature-ids))
        (features (list-type-advanced-features)))
    (expect (> (length ids) 0) :to-be-truthy)
    (expect (equal ids (sort (copy-list ids) #'string<)) :to-be-truthy)
    (expect (= (length ids) (length features)) :to-be-truthy)
    (expect (member "FR-1803" ids :test #'string=) :to-be-truthy))
  (expect (type-advanced-feature-id-for-head 'qtt) :to-equal "FR-3401")
  (expect (type-advanced-feature-id-for-head "QTT") :to-equal "FR-3401")
  (expect (type-advanced-feature-id-for-head 'not-a-registered-head) :to-be-null)
  (expect (type-advanced-head-p 'qtt) :to-be-truthy)
  (expect (type-advanced-head-p 'advanced) :to-be-truthy)
  (expect (type-advanced-head-p 'not-a-registered-head) :to-be-falsy)
  (expect (type-advanced-head-p 42) :to-be-falsy)
  (signals error (canonicalize-type-advanced-feature-id 42)))
