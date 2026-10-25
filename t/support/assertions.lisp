(in-package #:cl-cc/type-test-support)

(defmacro assert-when-present (value form)
  `(when ,value ,form))

(defun %matcher-expected-one (expected matcher)
  (unless (= (length expected) 1)
    (error "Matcher ~S expects one expected value, got ~D." matcher (length expected)))
  (first expected))

(defmatcher :to-be-type-equal-to (actual expected)
  (type-equal-p (%matcher-expected-one expected :to-be-type-equal-to) actual))

(defmatcher :to-unify-with (actual expected)
  (nth-value 1
    (type-unify (%matcher-expected-one expected :to-unify-with) actual)))
