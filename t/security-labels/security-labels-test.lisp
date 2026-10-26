;;;; t/types-extended-security-labels-test.lisp — Security-Label Lattice Tests
;;;;
;;;; Tests for src/security-labels/types-extended-security-labels.lisp:
;;;; the security-label lattice, join/meet, and labeled-value taint tracking.

(in-package #:cl-cc/type/security-labels/test)

(it-sequential "security-label-lattice-and-declassification-are-enforced"
  (expect (security-label<= :public :secret) :to-be-truthy)
  (expect (security-label<= :secret :public) :to-be-falsy)
  (expect (join-security-labels :trusted :secret) :to-be :secret)
  (expect (meet-security-labels :public :trusted) :to-be :public)
  (let* ((secret (make-labeled-value "token" :secret :tainted-p t))
         (sanitized (sanitize-labeled-value secret #'identity
                                                         :audit-entry '(:sanitize sql))))
    (expect (labeled-value-flow-allowed-p secret :public) :to-be-falsy)
    (expect (labeled-value-tainted-p sanitized) :to-be-falsy)
  (let ((public (declassify-labeled-value secret :public 'audit-log)))
      (expect (labeled-value-flow-allowed-p public :public) :to-be-truthy)
      (expect (length (labeled-value-audit-trail public)) :to-equal 1))))

(it-sequential "normalize-security-label-covers-all-four-designator-kinds"
  ;; DEFINE-KEYWORD-NORMALIZER (src/registry.lisp) expands its four-branch
  ;; COND separately at each call site, so this file's own coverage needs a
  ;; direct case for each branch: keyword, symbol, string, and "anything
  ;; else" -- the pre-existing test only ever passed keywords.
  (expect (normalize-security-label :public) :to-be :public)
  (expect (normalize-security-label 'public) :to-be :public)
  (expect (normalize-security-label "public") :to-be :public)
  (expect (normalize-security-label 42) :to-equal 42))

(it-sequential "security-label-rank-and-security-label-p-know-and-reject-labels"
  (expect (security-label-rank :public) :to-equal 0)
  (expect (security-label-rank :unknown-label) :to-be-null)
  (expect (security-label-p :secret) :to-be-truthy)
  (expect (security-label-p :unknown-label) :to-be-falsy))

(it-sequential "security-label<=-is-falsy-when-either-side-is-unknown"
  ;; The pre-existing test only drives (AND source-rank target-rank) with
  ;; two known labels; both ways of failing that AND need their own case.
  (expect (security-label<= :unknown-label :secret) :to-be-falsy)
  (expect (security-label<= :public :unknown-label) :to-be-falsy))

(it-sequential "join-and-meet-security-labels-signal-on-an-unknown-label"
  (signals error
      (join-security-labels :unknown-label :secret))
  (signals error
      (meet-security-labels :public :unknown-label)))

(it-sequential "make-labeled-value-rejects-an-unknown-label"
  (signals error
      (make-labeled-value "x" :unknown-label)))

(it-sequential "labeled-value-flow-allowed-p-accepts-a-bare-label-not-just-a-labeled-value"
  (expect (labeled-value-flow-allowed-p :public :secret) :to-be-truthy)
  (expect (labeled-value-flow-allowed-p :secret :public) :to-be-falsy))

(it-sequential "sanitize-labeled-value-without-a-sanitizer-preserves-the-payload"
  (let* ((original (make-labeled-value "token" :secret :tainted-p t))
         (sanitized (sanitize-labeled-value original nil)))
    (expect (labeled-value-value sanitized) :to-equal "token")
    (expect (labeled-value-tainted-p sanitized) :to-be-falsy)
    (expect (labeled-value-audit-trail sanitized) :to-be-null)))

(it-sequential "sanitize-labeled-value-rejects-a-non-labeled-value"
  (signals error
      (sanitize-labeled-value "not-a-labeled-value" #'identity)))

(it-sequential "declassify-labeled-value-rejects-invalid-inputs"
  (let ((secret (make-labeled-value "x" :secret)))
    (signals error
        (declassify-labeled-value "not-a-labeled-value" :public 'reason))
    (signals error
        (declassify-labeled-value secret :public nil))
    (signals error
        (declassify-labeled-value secret :unknown-label 'reason))
    ;; :public is LESS restrictive than :secret, so "declassifying" upward
    ;; to :top-secret must be rejected as an attempted restriction increase.
    (signals error
        (declassify-labeled-value secret :top-secret 'reason))))

