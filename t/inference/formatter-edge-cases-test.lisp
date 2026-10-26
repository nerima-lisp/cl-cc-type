(in-package #:cl-cc/type/inference/test)

(it-sequential "format-type-rejects-a-non-string-control-string"
  (signals error
      (format-type :not-a-string)))

(it-sequential "format-type-infers-float-and-char-directives"
  (let ((float-fn (format-type "~F"))
        (char-fn (format-type "~C")))
    (expect (first (type-arrow-params float-fn))
            :to-be-type-equal-to type-float)
    (expect (first (type-arrow-params char-fn))
            :to-be-type-equal-to type-char)))

(it-sequential "format-type-rejects-an-unsupported-directive"
  (signals error
      (format-type "~Z")))

(it-sequential "format-type-treats-a-doubled-tilde-as-a-literal-tilde-not-a-directive"
  (let ((fn (format-type "100~~ done")))
    (expect (type-arrow-params fn) :to-be-null)))

(it-sequential "format-type-tolerates-a-trailing-tilde-with-no-following-directive"
  (let ((fn (format-type "value~")))
    (expect (type-arrow-params fn) :to-be-null)))
