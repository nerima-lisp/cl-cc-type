;;;; t/types-extended-ffi-test.lisp — FFI Type Descriptors Tests
;;;;
;;;; Tests for src/types-extended-ffi.lisp:
;;;; recursive FFI descriptor validation and Lisp-type compatibility.

(in-package :cl-cc-type/test)

(it-sequential "ffi-descriptors-validate-recursively"
  (let* ((int (cl-cc/type:make-ffi-scalar-type 'int))
         (ptr (cl-cc/type:make-ffi-pointer-type int :borrowed-p t))
         (callback (cl-cc/type:make-ffi-callback-type (list int) int))
         (descriptor (cl-cc/type:make-ffi-function-descriptor 'strlen (list ptr callback) int)))
    (expect (cl-cc/type:ffi-type-valid-p int) :to-be-truthy)
    (expect (cl-cc/type:ffi-type-valid-p ptr) :to-be-truthy)
    (expect (cl-cc/type:ffi-type-valid-p callback) :to-be-truthy)
    (expect (cl-cc/type:ffi-type-valid-p descriptor) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer int) :to-be-truthy)
    (expect (cl-cc/type:ffi-descriptor-form-valid-p '(c-ptr)) :to-be-falsy)))

(it-sequential "make-ffi-scalar-type-normalizes-symbols-and-rejects-unknown-kinds"
  (expect (cl-cc/type:ffi-scalar-type-kind (cl-cc/type:make-ffi-scalar-type :double)) :to-be :double)
  (expect (cl-cc/type:ffi-scalar-type-kind (cl-cc/type:make-ffi-scalar-type 'bool)) :to-be :bool)
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:make-ffi-scalar-type 'not-a-kind)))

(it-sequential "make-ffi-pointer-type-tracks-borrowed-and-nullable-flags"
  (let* ((int (cl-cc/type:make-ffi-scalar-type :int))
         (ptr (cl-cc/type:make-ffi-pointer-type int :borrowed-p nil :nullable-p t)))
    (expect (cl-cc/type:ffi-pointer-type-borrowed-p ptr) :to-be-falsy)
    (expect (cl-cc/type:ffi-pointer-type-nullable-p ptr) :to-be-truthy)
    (expect (cl-cc/type:ffi-pointer-type-pointee ptr) :to-be int)))

(it-sequential "make-ffi-function-descriptor-defaults-and-custom-abi"
  (let* ((int (cl-cc/type:make-ffi-scalar-type :int))
         (default-abi (cl-cc/type:make-ffi-function-descriptor 'foo (list int) int))
         (custom-abi (cl-cc/type:make-ffi-function-descriptor 'bar (list int) int :abi :stdcall)))
    (expect (cl-cc/type:ffi-function-descriptor-abi default-abi) :to-be :c)
    (expect (cl-cc/type:ffi-function-descriptor-abi custom-abi) :to-be :stdcall)))

(it-sequential "ffi-type-valid-p-rejects-invalid-nested-descriptors"
  (let* ((int (cl-cc/type:make-ffi-scalar-type :int))
         (bad-ptr (cl-cc/type:make-ffi-pointer-type 42))
         (bad-callback (cl-cc/type:make-ffi-callback-type (list 42) int))
         (bad-fn-name (cl-cc/type:make-ffi-function-descriptor 42 (list int) int)))
    (expect (cl-cc/type:ffi-type-valid-p bad-ptr) :to-be-falsy)
    (expect (cl-cc/type:ffi-type-valid-p bad-callback) :to-be-falsy)
    (expect (cl-cc/type:ffi-type-valid-p bad-fn-name) :to-be-falsy)
    (expect (cl-cc/type:ffi-type-valid-p 42) :to-be-falsy)))

(it-sequential "ffi-lisp-type-compatible-p-covers-every-scalar-kind-and-non-scalar-descriptors"
  (let* ((int (cl-cc/type:make-ffi-scalar-type :int))
         (flt (cl-cc/type:make-ffi-scalar-type :float))
         (dbl (cl-cc/type:make-ffi-scalar-type :double))
         (str (cl-cc/type:make-ffi-scalar-type :string))
         (bl  (cl-cc/type:make-ffi-scalar-type :bool))
         (vd  (cl-cc/type:make-ffi-scalar-type :void))
         (ch  (cl-cc/type:make-ffi-scalar-type :char))
         (ptr (cl-cc/type:make-ffi-pointer-type int))
         (callback (cl-cc/type:make-ffi-callback-type (list int) int)))
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'fixnum int) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'string int) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'single-float flt) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer flt) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'double-float dbl) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer dbl) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'string str) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer str) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'boolean bl) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer bl) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'anything-at-all vd) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'anything-at-all ch) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'cl-cc/type::system-area-pointer ptr) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer ptr) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'function callback) :to-be-truthy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer callback) :to-be-falsy)
    (expect (cl-cc/type:ffi-lisp-type-compatible-p 'integer 42) :to-be-falsy)))

(it-sequential "ffi-descriptor-form-valid-p-rejects-a-callback-form-with-the-wrong-arity"
  ;; The pre-existing (C-CALLBACK ...) cases both happen to have exactly 2
  ;; elements, so the (= (LENGTH value) 2) conjunct's own false side (as
  ;; opposed to (SECOND value)'s false side, already covered by
  ;; `(c-callback nil)`) was never taken.
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(c-callback)) :to-be-falsy))

(it-sequential "ffi-descriptor-from-form-rejects-a-head-too-short-to-carry-a-c-prefix"
  ;; %FFI-SCALAR-KIND-FROM-NAME only strips a "C-" prefix when the head
  ;; name is long enough to contain one; a 1-character head name skips
  ;; that stripping and is looked up as-is, which fails.
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form (list 'c 'foo))))

(it-sequential "ffi-descriptor-form-valid-p-covers-atoms-scalars-callbacks-and-recursive-forms"
  (expect (cl-cc/type:ffi-descriptor-form-valid-p cl-cc/type:type-int) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p 42) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p 'int) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(c-int x)) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(c-string y)) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(c-callback some-signature)) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(c-callback nil)) :to-be-falsy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(wrap (c-int x) (c-string y))) :to-be-truthy)
  (expect (cl-cc/type:ffi-descriptor-form-valid-p '(wrap (c-ptr))) :to-be-falsy))

(it-sequential "ffi-descriptor-from-form-passes-through-existing-descriptor-objects"
  (let ((int (cl-cc/type:make-ffi-scalar-type :int)))
    (expect (cl-cc/type:ffi-descriptor-from-form int) :to-be int)))

(it-sequential "ffi-descriptor-from-form-builds-scalar-pointer-callback-and-function-descriptors-from-forms"
  (let ((scalar (cl-cc/type:ffi-descriptor-from-form "double")))
    (expect (cl-cc/type:ffi-scalar-type-p scalar) :to-be-truthy)
    (expect (cl-cc/type:ffi-scalar-type-kind scalar) :to-be :double))
  (let ((ptr (cl-cc/type:ffi-descriptor-from-form '(c-ptr int))))
    (expect (cl-cc/type:ffi-pointer-type-p ptr) :to-be-truthy)
    (expect (cl-cc/type:ffi-scalar-type-kind (cl-cc/type:ffi-pointer-type-pointee ptr)) :to-be :int))
  (let ((callback (cl-cc/type:ffi-descriptor-from-form '(c-callback (int) string))))
    (expect (cl-cc/type:ffi-callback-type-p callback) :to-be-truthy)
    (expect (length (cl-cc/type:ffi-callback-type-argument-types callback)) :to-equal 1)
    (expect (cl-cc/type:ffi-scalar-type-kind (cl-cc/type:ffi-callback-type-return-type callback))
            :to-be :string))
  (let ((fn (cl-cc/type:ffi-descriptor-from-form '(foreign strlen ((c-ptr char)) int))))
    (expect (cl-cc/type:ffi-function-descriptor-p fn) :to-be-truthy)
    (expect (cl-cc/type:ffi-function-descriptor-name fn) :to-be 'strlen)
    (expect (length (cl-cc/type:ffi-function-descriptor-argument-types fn)) :to-equal 1)
    (expect (cl-cc/type:ffi-scalar-type-kind (cl-cc/type:ffi-function-descriptor-return-type fn))
            :to-be :int))
  (let ((recursed (cl-cc/type:ffi-descriptor-from-form '(int))))
    (expect (cl-cc/type:ffi-scalar-type-p recursed) :to-be-truthy)
    (expect (cl-cc/type:ffi-scalar-type-kind recursed) :to-be :int)))

(it-sequential "ffi-descriptor-from-form-accepts-a-string-head-and-rejects-a-non-symbolic-head"
  ;; %FFI-SYMBOL-NAME's STRINGP arm and its final NIL fallback (for a head
  ;; that is neither a symbol nor a string) are both reached only through
  ;; a cons descriptor form's HEAD; every pre-existing cons-form test uses
  ;; a symbol head.
  (let ((ptr (cl-cc/type:ffi-descriptor-from-form (list "c-ptr" 'int))))
    (expect (cl-cc/type:ffi-pointer-type-p ptr) :to-be-truthy))
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form (list 42 'foo))))

(it-sequential "ffi-descriptor-from-form-signals-ffi-validation-error-on-malformed-or-unknown-forms"
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form 'not-a-known-scalar))
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form '(c-ptr)))
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form '(c-callback (int))))
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form '(foreign strlen (int))))
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form '(totally-unknown-head 1 2)))
  (signals cl-cc/type:ffi-validation-error
      (cl-cc/type:ffi-descriptor-from-form 42)))

(it-sequential "ffi-descriptor-lisp-type-maps-scalar-kinds-to-the-canonical-lisp-type-singletons"
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :int))
          :to-be cl-cc/type:type-int)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :short))
          :to-be cl-cc/type:type-int)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :long))
          :to-be cl-cc/type:type-int)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :size-t))
          :to-be cl-cc/type:type-int)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :float))
          :to-be cl-cc/type:type-float)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :double))
          :to-be cl-cc/type:type-float)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :string))
          :to-be cl-cc/type:type-string)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :bool))
          :to-be cl-cc/type:type-bool)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :void))
          :to-be cl-cc/type:type-null)
  (expect (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-scalar-type :char))
          :to-be cl-cc/type:type-char))

(it-sequential "ffi-descriptor-lisp-type-builds-pointer-and-arrow-types-and-accepts-raw-descriptor-forms"
  (let ((int (cl-cc/type:make-ffi-scalar-type :int)))
    (expect (cl-cc/type:type-primitive-name
             (cl-cc/type:ffi-descriptor-lisp-type (cl-cc/type:make-ffi-pointer-type int)))
            :to-be 'cl-cc/type::foreign-pointer))
  (let* ((callback (cl-cc/type:make-ffi-callback-type
                     (list (cl-cc/type:make-ffi-scalar-type :int))
                     (cl-cc/type:make-ffi-scalar-type :bool)))
         (arrow (cl-cc/type:ffi-descriptor-lisp-type callback)))
    (expect (cl-cc/type:type-arrow-p arrow) :to-be-truthy)
    (expect (length (cl-cc/type:type-arrow-params arrow)) :to-equal 1)
    (expect (first (cl-cc/type:type-arrow-params arrow)) :to-be-type-equal-to cl-cc/type:type-int)
    (expect (cl-cc/type:type-arrow-return arrow) :to-be-type-equal-to cl-cc/type:type-bool))
  (let* ((fn (cl-cc/type:make-ffi-function-descriptor
              'strlen
              (list (cl-cc/type:make-ffi-pointer-type (cl-cc/type:make-ffi-scalar-type :char)))
              (cl-cc/type:make-ffi-scalar-type :int)))
         (arrow (cl-cc/type:ffi-descriptor-lisp-type fn)))
    (expect (cl-cc/type:type-arrow-p arrow) :to-be-truthy)
    (expect (length (cl-cc/type:type-arrow-params arrow)) :to-equal 1)
    (expect (cl-cc/type:type-arrow-return arrow) :to-be-type-equal-to cl-cc/type:type-int))
  (expect (cl-cc/type:ffi-descriptor-lisp-type 'int) :to-be cl-cc/type:type-int)
  (expect (cl-cc/type:ffi-descriptor-lisp-type "double") :to-be cl-cc/type:type-float))

