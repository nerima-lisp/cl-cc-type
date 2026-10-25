(in-package #:cl-cc/type/security-labels/test)

(it-sequential "advanced-validate-information-flow-fr-1503-checks-target-rank-and-declassification-evidence"
  ;; Unknown :flow target label is rejected outright.
  (signals error
      (make-type-advanced :feature-id "FR-1503" :name 'advanced :args (list '(secret 1)) :properties (list (cons :flow :nonexistent-label))))
  ;; Downgrading a secret source to a public target requires evidence.
  (signals error
      (make-type-advanced :feature-id "FR-1503" :name 'advanced :args (list '(secret 1)) :properties (list (cons :flow :public))))
  ;; The same downgrade succeeds once declassification evidence is supplied.
  (let ((node (make-type-advanced :feature-id "FR-1503" :name 'advanced :args (list '(secret 1)) :properties (list (cons :flow :public)) :evidence '(declassify audited))))
    (expect (type-advanced-valid-p node) :to-be-truthy))
  ;; Upgrading a public source to a secret target never needs evidence.
  (let ((node (make-type-advanced :feature-id "FR-1503" :name 'advanced :args (list '(public 1)) :properties (list (cons :flow :secret)))))
    (expect (type-advanced-valid-p node) :to-be-truthy))
  ;; With no :flow target at all, the source/target comparison is skipped entirely.
  (let ((node (make-type-advanced :feature-id "FR-1503" :name 'advanced :args (list '(secret 1)))))
    (expect (type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "type-advanced-payload-security-label-covers-every-label-and-both-fallbacks"
  (expect (%type-advanced-payload-security-label '(public x)) :to-be :public)
  (expect (%type-advanced-payload-security-label '(trusted x)) :to-be :trusted)
  (expect (%type-advanced-payload-security-label '(tainted x)) :to-be :tainted)
  (expect (%type-advanced-payload-security-label '(secret x)) :to-be :secret)
  (expect (%type-advanced-payload-security-label '(top-secret x)) :to-be :top-secret)
  (expect (%type-advanced-payload-security-label '(unlabeled x)) :to-be-null)
  (expect (%type-advanced-payload-security-label "not-a-cons-form") :to-be-null))

(it-sequential "type-advanced-head-name-is-nil-for-a-non-cons-value"
  (expect (%type-advanced-head-name '(public x)) :to-equal "PUBLIC")
  (expect (%type-advanced-head-name 42) :to-be-null))
