;;;; Tests for the standalone type syntax protocol.

(defpackage #:cl-cc/type/syntax/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/syntax #:looks-like-type-specifier-p #:parse-type-specifier #:type-to-string #:unparse-type))
