;;;; t/types-extended-registries-test.lisp — Advanced Dispatch Registries Tests
;;;;
;;;; Tests for src/types-extended-registries.lisp:
;;;; type-interface-module registration/lookup, the SMT-solver, type-checker
;;;; plugin, and type-synthesis-strategy registries built via DEFINE-REGISTRY,
;;;; their dispatch functions' "no handler registered" error paths, and the
;;;; deterministic default handler shims.

(in-package :cl-cc/type/type-lowering/test)

(it-sequential "register-type-interface-returns-a-summary-and-lookup-type-interface-finds-it"
  (let ((summary (register-type-interface
                   'registries-test-module
                   '((registries-test-fn-a fixnum) (registries-test-fn-b))
                   "fingerprint-registries-1")))
    (expect (type-interface-module-p summary) :to-be-truthy)
    (expect (type-interface-module-name summary) :to-be 'registries-test-module)
    (expect (type-interface-module-fingerprint summary)
            :to-equal "fingerprint-registries-1")
    (expect (type-interface-module-exports summary)
            :to-equal '(registries-test-fn-a registries-test-fn-b))
    (let ((found (lookup-type-interface 'registries-test-module)))
      (expect found :to-be summary))))

(it-sequential "register-type-interface-handles-cons-and-bare-symbol-exports"
  ;; Exercises both branches of the internal export-name/export-type helpers:
  ;; a (name type) cons, a (name) cons with no type, and a bare symbol export.
  (let ((summary (register-type-interface
                   'registries-mixed-export-module
                   '((registries-export-typed fixnum)
                     (registries-export-untyped)
                     registries-export-bare)
                   "fingerprint-registries-mixed")))
    (expect (type-interface-module-exports summary)
            :to-equal '(registries-export-typed registries-export-untyped registries-export-bare))
    (let ((typed-entry (assoc 'registries-export-typed
                               (type-interface-module-exported-types summary))))
      (expect (type-primitive-p (cdr typed-entry)) :to-be-truthy)
      (expect (type-primitive-name (cdr typed-entry)) :to-be 'fixnum))
    (let ((untyped-entry (assoc 'registries-export-untyped
                                 (type-interface-module-exported-types summary))))
      (expect (cdr untyped-entry) :to-be-type-equal-to type-any))
    (let ((bare-entry (assoc 'registries-export-bare
                              (type-interface-module-exported-types summary))))
      (expect (cdr bare-entry) :to-be-type-equal-to type-any)))
  (multiple-value-bind (scheme found-p)
      (lookup-type-interface-export 'registries-export-bare)
    (expect found-p :to-be-truthy)
    (expect (type-scheme-p scheme) :to-be-truthy)))

(in-package :cl-cc/type/type-lowering/test)

(it-sequential "register-type-interface-accepts-a-string-module-name"
  (let ((summary (register-type-interface
                   "STRING-NAMED-REGISTRIES-MODULE"
                   '((registries-test-string-fn fixnum))
                   "fingerprint-registries-string")))
    (expect (type-interface-module-p summary) :to-be-truthy)
    (expect (lookup-type-interface "STRING-NAMED-REGISTRIES-MODULE") :to-be summary)))

(it-sequential "subtype-class-shape-satisfies-registered-protocol"
  (let ((*class-type-registry* (make-hash-table :test #'eq))
        (*class-method-type-registry* (make-hash-table :test #'eq))
        (*protocol-type-registry* (make-hash-table :test #'eq)))
    (register-protocol-type 'drawable '(draw))
    (register-class-type
     'sprite
     (list (cons 'x type-int)))
    (register-class-method-type
     'sprite 'draw (make-type-primitive :name 'function))
    (expect
     (is-subtype-p (make-type-primitive :name (quote sprite)) (make-type-constructor (quote protocol) (list (make-type-primitive :name (quote drawable)))))
     :to-be-truthy)
    (expect
     (is-subtype-p (make-type-primitive :name (quote point)) (make-type-constructor (quote protocol) (list (make-type-primitive :name (quote drawable)))))
     :to-be-falsy)))

(it-sequential "register-protocol-type-name-and-type-node-pair"
  (let ((*protocol-type-registry* (make-hash-table :test #'eq)))
    (register-protocol-type 'sized `((size ,type-int)))
    (let ((fields (lookup-protocol-type 'sized)))
      (expect fields :to-be-truthy)
      (expect (cdr (first fields)) :to-be-type-equal-to type-int))))

(it-sequential "register-protocol-type-invalid-spec-signals-error"
  (signals error
    (register-protocol-type 'malformed (list 42))))
