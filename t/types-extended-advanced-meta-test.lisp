;;;; t/types-extended-advanced-meta-test.lisp — Advanced feature/head registry tests
;;;;
;;;; Tests for src/types-extended-advanced-meta.lisp. register-type-advanced-feature
;;;; and register-type-advanced-head also run once at load time (from
;;;; %initialize-type-advanced-feature-registry, seeding every real FR id), so these
;;;; tests register additional test-only entries under a "FR-9999*" id rather than
;;;; re-registering real ids, to exercise the same code paths without disturbing the
;;;; production registry state other test files rely on.

(in-package :cl-cc-type/test)

(it-sequential "type-advanced-feature-constructor-and-accessors"
  (let ((feature (cl-cc/type:make-type-advanced-feature
                  :id "fr-9999-meta-test"
                  :title "Meta Test Feature"
                  :heads '(seed-head))))
    (expect (cl-cc/type:type-advanced-feature-p feature) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-fr-id feature) :to-equal "FR-9999-META-TEST")
    (expect (cl-cc/type:type-advanced-feature-title feature) :to-equal "Meta Test Feature")
    (expect (cl-cc/type:type-advanced-feature-heads feature) :to-equal '(seed-head))))

(it-sequential "register-and-lookup-type-advanced-feature-round-trips"
  (cl-cc/type:register-type-advanced-feature
   (cl-cc/type:make-type-advanced-feature :id 'fr-9999-round-trip :title "Round Trip"))
  (let ((found (cl-cc/type:lookup-type-advanced-feature "fr-9999-round-trip")))
    (expect (cl-cc/type:type-advanced-feature-p found) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-fr-id found) :to-equal "FR-9999-ROUND-TRIP")
    (expect (cl-cc/type:type-advanced-feature-title found) :to-equal "Round Trip"))
  (expect (member "FR-9999-ROUND-TRIP" (cl-cc/type:list-type-advanced-feature-ids)
                  :test #'string=)
          :to-be-truthy))

(it-sequential "lookup-type-advanced-feature-unregistered-id-returns-nil"
  (expect (cl-cc/type:lookup-type-advanced-feature "fr-9999-never-registered") :to-be-null))

(it-sequential "register-type-advanced-head-unknown-feature-id-signals-error"
  (signals error
      (cl-cc/type::register-type-advanced-head 'fr-9999-orphan-head "fr-9999-does-not-exist")))

(it-sequential "register-type-advanced-head-adds-head-to-feature-heads"
  (cl-cc/type:register-type-advanced-feature
   (cl-cc/type:make-type-advanced-feature :id 'fr-9999-head-owner :title "Head Owner"))
  (cl-cc/type::register-type-advanced-head 'fr-9999-new-head 'fr-9999-head-owner)
  (expect (cl-cc/type:type-advanced-feature-id-for-head 'fr-9999-new-head)
          :to-equal "FR-9999-HEAD-OWNER")
  (expect (cl-cc/type:type-advanced-head-p 'fr-9999-new-head) :to-be-truthy)
  (expect (member "FR-9999-NEW-HEAD"
                  (cl-cc/type:type-advanced-feature-heads
                   (cl-cc/type:lookup-type-advanced-feature 'fr-9999-head-owner))
                  :test #'string=)
          :to-be-truthy))

(it-sequential "register-type-advanced-head-accepts-a-raw-string-head"
  ;; The pre-existing tests only ever pass a symbol HEAD; REGISTER-TYPE-
  ;; ADVANCED-HEAD's own (IF (SYMBOLP head) (SYMBOL-NAME head) head)
  ;; branch for an already-string head was never taken.
  (cl-cc/type:register-type-advanced-feature
   (cl-cc/type:make-type-advanced-feature :id 'fr-9999-string-head-owner :title "String Head Owner"))
  (cl-cc/type::register-type-advanced-head "fr-9999-string-head" 'fr-9999-string-head-owner)
  (expect (cl-cc/type:type-advanced-feature-id-for-head "fr-9999-string-head")
          :to-equal "FR-9999-STRING-HEAD-OWNER"))

(it-sequential "type-advanced-head-p-accepts-a-raw-string-head"
  ;; Mirrors the string-head coverage above, but for TYPE-ADVANCED-HEAD-P's
  ;; own (IF (SYMBOLP head) ...) branch specifically -- the pre-existing
  ;; string-argument test for this function's sibling,
  ;; TYPE-ADVANCED-FEATURE-ID-FOR-HEAD, does not also exercise this one.
  (expect (cl-cc/type:type-advanced-head-p "qtt") :to-be-truthy))

(it-sequential "type-advanced-feature-id-for-head-is-nil-for-a-non-symbol-non-string-head"
  ;; TYPE-ADVANCED-HEAD-P already has a non-symbol/non-string case (42);
  ;; TYPE-ADVANCED-FEATURE-ID-FOR-HEAD's own (OR (SYMBOLP head) (STRINGP
  ;; head)) guard needs its own, since falling through to the shared
  ;; registry lookup would otherwise never be skipped for this function.
  (expect (cl-cc/type:type-advanced-feature-id-for-head 42) :to-be-null))
