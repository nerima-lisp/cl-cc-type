(in-package #:cl-cc/type/concurrency/test)

(describe "concurrency feature tests"
  (load (asdf:system-relative-pathname
         "cl-cc-type/test" "t/concurrency/concurrency-test.lisp")))
