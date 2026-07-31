;;;; t/types-extended-security-labels-test.lisp — Security-Label Lattice Tests
;;;;
;;;; Tests for src/types-extended-security-labels.lisp:
;;;; the security-label lattice, join/meet, and labeled-value taint tracking.

(in-package :cl-cc-type/test)

(it-sequential "security-label-lattice-and-declassification-are-enforced"
  (expect (cl-cc/type:security-label<= :public :secret) :to-be-truthy)
  (expect (cl-cc/type:security-label<= :secret :public) :to-be-falsy)
  (expect (cl-cc/type:join-security-labels :trusted :secret) :to-be :secret)
  (expect (cl-cc/type:meet-security-labels :public :trusted) :to-be :public)
  (let* ((secret (cl-cc/type:make-labeled-value "token" :secret :tainted-p t))
         (sanitized (cl-cc/type:sanitize-labeled-value secret #'identity
                                                         :audit-entry '(:sanitize sql))))
    (expect (cl-cc/type:labeled-value-flow-allowed-p secret :public) :to-be-falsy)
    (expect (cl-cc/type:labeled-value-tainted-p sanitized) :to-be-falsy)
  (let ((public (cl-cc/type:declassify-labeled-value secret :public 'audit-log)))
      (expect (cl-cc/type:labeled-value-flow-allowed-p public :public) :to-be-truthy)
      (expect (length (cl-cc/type:labeled-value-audit-trail public)) :to-equal 1))))

(it-sequential "normalize-security-label-covers-all-four-designator-kinds"
  ;; DEFINE-KEYWORD-NORMALIZER (src/registry.lisp) expands its four-branch
  ;; COND separately at each call site, so this file's own coverage needs a
  ;; direct case for each branch: keyword, symbol, string, and "anything
  ;; else" -- the pre-existing test only ever passed keywords.
  (expect (cl-cc/type:normalize-security-label :public) :to-be :public)
  (expect (cl-cc/type:normalize-security-label 'public) :to-be :public)
  (expect (cl-cc/type:normalize-security-label "public") :to-be :public)
  (expect (cl-cc/type:normalize-security-label 42) :to-equal 42))

(it-sequential "security-label-rank-and-security-label-p-know-and-reject-labels"
  (expect (cl-cc/type:security-label-rank :public) :to-equal 0)
  (expect (cl-cc/type:security-label-rank :unknown-label) :to-be-null)
  (expect (cl-cc/type:security-label-p :secret) :to-be-truthy)
  (expect (cl-cc/type:security-label-p :unknown-label) :to-be-falsy))

(it-sequential "security-label<=-is-falsy-when-either-side-is-unknown"
  ;; The pre-existing test only drives (AND source-rank target-rank) with
  ;; two known labels; both ways of failing that AND need their own case.
  (expect (cl-cc/type:security-label<= :unknown-label :secret) :to-be-falsy)
  (expect (cl-cc/type:security-label<= :public :unknown-label) :to-be-falsy))

(it-sequential "join-and-meet-security-labels-signal-on-an-unknown-label"
  (signals error
      (cl-cc/type:join-security-labels :unknown-label :secret))
  (signals error
      (cl-cc/type:meet-security-labels :public :unknown-label)))

(it-sequential "make-labeled-value-rejects-an-unknown-label"
  (signals error
      (cl-cc/type:make-labeled-value "x" :unknown-label)))

(it-sequential "labeled-value-flow-allowed-p-accepts-a-bare-label-not-just-a-labeled-value"
  (expect (cl-cc/type:labeled-value-flow-allowed-p :public :secret) :to-be-truthy)
  (expect (cl-cc/type:labeled-value-flow-allowed-p :secret :public) :to-be-falsy))

(it-sequential "sanitize-labeled-value-without-a-sanitizer-preserves-the-payload"
  (let* ((original (cl-cc/type:make-labeled-value "token" :secret :tainted-p t))
         (sanitized (cl-cc/type:sanitize-labeled-value original nil)))
    (expect (cl-cc/type:labeled-value-value sanitized) :to-equal "token")
    (expect (cl-cc/type:labeled-value-tainted-p sanitized) :to-be-falsy)
    (expect (cl-cc/type:labeled-value-audit-trail sanitized) :to-be-null)))

(it-sequential "sanitize-labeled-value-rejects-a-non-labeled-value"
  (signals error
      (cl-cc/type:sanitize-labeled-value "not-a-labeled-value" #'identity)))

(it-sequential "declassify-labeled-value-rejects-invalid-inputs"
  (let ((secret (cl-cc/type:make-labeled-value "x" :secret)))
    (signals error
        (cl-cc/type:declassify-labeled-value "not-a-labeled-value" :public 'reason))
    (signals error
        (cl-cc/type:declassify-labeled-value secret :public nil))
    (signals error
        (cl-cc/type:declassify-labeled-value secret :unknown-label 'reason))
    ;; :public is LESS restrictive than :secret, so "declassifying" upward
    ;; to :top-secret must be rejected as an attempted restriction increase.
    (signals error
        (cl-cc/type:declassify-labeled-value secret :top-secret 'reason))))

