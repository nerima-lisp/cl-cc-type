;;;; t/type-2026-advanced-semantic-tests.lisp - 2026 Concrete Advanced Type Semantic Tests
;;;;
;;;; Covers: concurrency traits, security labels, generics, channels, actors, STM, coroutines,
;;;; SIMD, routing, utility types, regions, capabilities, units, FFI, QTT, CIC, termination,
;;;; validators, and advanced contract enforcement tests.

(in-package :cl-cc-type/test)

;;; ─── Concrete advanced semantic API regression tests (merged for Nix flake source) ─

(it-sequential "concurrency-send-sync-registry-is-concrete"
  (cl-cc/type:register-concurrency-traits 'mutex-guard :send nil :sync nil :note :host-only)
  (cl-cc/type:register-concurrency-traits 'immutable-box :send t :sync t :note :value-object)
  (expect (cl-cc/type:sendable-type-p 'mutex-guard) :to-be-falsy)
  (expect (cl-cc/type:shareable-type-p 'mutex-guard) :to-be-falsy)
  (expect (cl-cc/type:validate-spawn-argument 'immutable-box) :to-be-truthy)
  (expect (cl-cc/type:validate-shared-reference 'immutable-box) :to-be-truthy)
  (expect (cl-cc/type:sendable-type-p 'integer) :to-be-truthy))

(it-sequential "security-label-lattice-and-declassification-are-enforced"
  (expect (cl-cc/type:security-label<= :public :secret) :to-be-truthy)
  (expect (cl-cc/type:security-label<= :secret :public) :to-be-falsy)
  (expect (cl-cc/type:join-security-labels :trusted :secret) :to-be :secret)
  (expect (cl-cc/type:meet-security-labels :public :trusted) :to-be :public)
  (let* ((secret (cl-cc/type:make-labeled-value "token" :secret :tainted-p t))
         (sanitized (cl-cc/type:sanitize-labeled-value secret #'identity :audit-entry '(:sanitize sql))))
    (expect (cl-cc/type:labeled-value-flow-allowed-p secret :public) :to-be-falsy)
    (expect (cl-cc/type:labeled-value-tainted-p sanitized) :to-be-falsy)
  (let ((public (cl-cc/type:declassify-labeled-value secret :public 'audit-log)))
      (expect (cl-cc/type:labeled-value-flow-allowed-p public :public) :to-be-truthy)
      (expect (length (cl-cc/type:labeled-value-audit-trail public)) :to-equal 1))))

(it-sequential "concrete-generics-registry-and-structural-traversal-work"
  (let* ((table cl-cc/type:*generic-instance-registry*)
         (saved (cl-cc/type:lookup-generic-instance 'keyword)))
    (unwind-protect
        (progn
          (cl-cc/type:register-generic-instance
           'keyword
           (lambda (value)
             (cl-cc/type:make-generic-sum
              :tag :keyword
              :value (cl-cc/type:make-generic-k1 :value value :type 'keyword)))
           :show (lambda (value) (string-downcase (symbol-name value)))
           :traverse (lambda (fn value) (funcall fn value)))
          (let ((representation (cl-cc/type:generic-representation-of :TOKEN)))
            (expect (cl-cc/type:generic-sum-p representation) :to-be-truthy)
            (expect (cl-cc/type:generic-representation-valid-p representation) :to-be-truthy)
            (expect (cl-cc/type:generic-show :TOKEN) :to-equal "token"))
          (expect (cl-cc/type:generic-transform #'1+ '(1 2 3)) :to-equal '(2 3 4))
          (expect (cl-cc/type:generic-query #'evenp '(1 2 3 4)) :to-equal '(2 4)))
      (if saved
          (setf (gethash 'keyword table) saved)
          (remhash 'keyword table)))))

(it-sequential "generic-representation-of-unregistered-type-branches"
  (expect (cl-cc/type:generic-u1-p (cl-cc/type:generic-representation-of nil))
          :to-be-truthy)
  (let ((rep (cl-cc/type:generic-representation-of (cons 1 2))))
    (expect (cl-cc/type:generic-product-p rep) :to-be-truthy)
    (expect (cl-cc/type:generic-k1-p (cl-cc/type:generic-product-left rep))
            :to-be-truthy)
    (expect (cl-cc/type:generic-k1-value (cl-cc/type:generic-product-left rep))
            :to-equal 1))
  (let ((rep (cl-cc/type:generic-representation-of 42)))
    (expect (cl-cc/type:generic-k1-p rep) :to-be-truthy)
    (expect (cl-cc/type:generic-k1-value rep) :to-equal 42)))

(it-sequential "generic-show-unregistered-type-branches"
  (expect (cl-cc/type:generic-show (list 1 2 3)) :to-equal "(1 2 3)")
  (expect (cl-cc/type:generic-show 42) :to-equal "42"))

(it-sequential "generic-transform-uses-registered-traverse-hook"
  (let* ((table cl-cc/type:*generic-instance-registry*)
         (saved (cl-cc/type:lookup-generic-instance 'symbol)))
    (unwind-protect
        (progn
          (cl-cc/type:register-generic-instance
           'symbol nil
           :traverse (lambda (fn value) (funcall fn (symbol-name value))))
          (expect (cl-cc/type:generic-transform #'string-downcase 'HELLO)
                  :to-equal "hello"))
      (if saved
          (setf (gethash 'symbol table) saved)
          (remhash 'symbol table)))))

(it-sequential "generic-representation-valid-p-covers-every-representation-kind"
  (expect (cl-cc/type:generic-representation-valid-p (cl-cc/type:make-generic-u1))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-k1 :value 1 :type 'fixnum))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-m1 :meta :m :representation (cl-cc/type:make-generic-u1)))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-product
            :left (cl-cc/type:make-generic-u1)
            :right (cl-cc/type:make-generic-u1)))
          :to-be-truthy)
  (expect (cl-cc/type:generic-representation-valid-p
           (cl-cc/type:make-generic-product
            :left (cl-cc/type:make-generic-u1)
            :right 42))
          :to-be-falsy)
  (expect (cl-cc/type:generic-representation-valid-p 42) :to-be-falsy))

(it-sequential "concrete-channels-enforce-capacity-type-and-close-semantics"
  (multiple-value-bind (sender receiver) (cl-cc/type:make-buffered-channel 'integer 1)
    (expect (cl-cc/type:channel-payload-type sender) :to-be 'integer)
    (expect (cl-cc/type:channel-send sender 7) :to-be-truthy)
    (signals error
        (cl-cc/type:channel-send sender 8))
    (expect (cl-cc/type:channel-recv receiver) :to-equal 7)
    (expect (cl-cc/type:channel-recv receiver) :to-be-null)
    (signals error
        (cl-cc/type:channel-send sender "wrong"))
    (cl-cc/type:close-typed-channel sender)
    (signals error
        (cl-cc/type:channel-send sender 9))))

(it-sequential "concrete-actors-accept-typed-messages-and-stop-cleanly"
  (let* ((seen nil)
         (actor (cl-cc/type:make-actor-ref '(:ping integer)
                                           :handler (lambda (message) (setf seen message)))))
    (expect (cl-cc/type:actor-message-accepted-p actor '(:ping 5)) :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor '(:pong 5)) :to-be-falsy)
    (expect (cl-cc/type:actor-send actor '(:ping 5)) :to-be-truthy)
    (expect seen :to-equal '(:ping 5))
    (cl-cc/type:actor-stop actor)
    (expect (cl-cc/type:actor-message-accepted-p actor '(:ping 6)) :to-be-falsy)
    (signals error
        (cl-cc/type:actor-send actor '(:ping 6)))))

(it-sequential "concrete-stm-actions-sequence-and-reject-io-effects"
  (let* ((cell (cl-cc/type:make-tvar 'integer 1))
         (action (cl-cc/type:stm-bind
                  (cl-cc/type:stm-read cell)
                  (lambda (current)
                    (cl-cc/type:stm-bind
                     (cl-cc/type:stm-write cell (+ current 1))
                     (lambda (_)
                       (declare (ignore _))
                       (cl-cc/type:stm-read cell)))))))
    (expect (cl-cc/type:atomically action) :to-equal 2)
    (expect (cl-cc/type:atomically (cl-cc/type:stm-read cell)) :to-equal 2)
    (signals error
        (cl-cc/type:atomically
         (cl-cc/type::%make-stm-action :result-type cl-cc/type:type-int
                                       :thunk (lambda () 0)
                                       :effects '(:io))))))

(it-sequential "concrete-coroutines-generators-and-coroutines-enforce-runtime-types"
  (let ((generator (cl-cc/type:make-generator 'integer '(1 2)
                                              :return-type 'string
                                              :final-value "done")))
    (multiple-value-bind (value done-p) (cl-cc/type:generator-next generator)
      (expect value :to-equal 1)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (cl-cc/type:generator-next generator)
      (expect value :to-equal 2)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (cl-cc/type:generator-next generator)
      (expect value :to-equal "done")
      (expect done-p :to-be-truthy)))
  (let ((coroutine (cl-cc/type:make-coroutine
                    'integer 'integer 'string
                    (lambda (value)
                      (if (plusp value)
                          (values (+ value 1) nil)
                          (values "done" t))))))
    (multiple-value-bind (value done-p) (cl-cc/type:coroutine-resume coroutine 3)
      (expect value :to-equal 4)
      (expect done-p :to-be-falsy))
    (multiple-value-bind (value done-p) (cl-cc/type:coroutine-resume coroutine 0)
      (expect value :to-equal "done")
      (expect done-p :to-be-truthy)))
  (signals error
      (let ((coroutine (cl-cc/type:make-coroutine
                        'integer 'integer 'string
                        (lambda (_value)
                          (declare (ignore _value))
                          (values :wrong nil)))))
        (cl-cc/type:coroutine-resume coroutine 1))))

(it-sequential "concrete-simd-vectors-preserve-lanes-and-element-types"
  (let* ((left (cl-cc/type:make-simd-vector 'integer '(1 2 3)))
         (right (cl-cc/type:make-simd-vector 'integer '(4 5 6)))
         (sum (cl-cc/type:simd-add left right))
         (mapped (cl-cc/type:simd-map (lambda (value) (* value 2)) left)))
    (expect (cl-cc/type:simd-vector-lanes sum) :to-equal 3)
    (expect (cl-cc/type:simd-vector-values sum) :to-equal '(5 7 9))
    (expect (cl-cc/type:simd-vector-values mapped) :to-equal '(2 4 6))
    (signals error
        (cl-cc/type:simd-add left (cl-cc/type:make-simd-vector 'integer '(1 2))))))

(it-sequential "concrete-routing-api-lookup-and-response-type-work"
  (let* ((users (cl-cc/type:make-route :get "/users/{id}"
                                       :parameters '((id integer))
                                       :response-type 'user))
         (health (cl-cc/type:make-route :get "/health"
                                        :parameters nil
                                        :response-type 'status))
         (api-spec (cl-cc/type::make-api-spec :routes (list users health)))
         (api-type (cl-cc/type:make-api-type :get "/users/{id}" '((id integer)) 'user)))
    (expect (cl-cc/type:type-advanced-p api-type) :to-be-truthy)
    (expect (cl-cc/type:api-spec-valid-p api-spec) :to-be-truthy)
    (multiple-value-bind (route params) (cl-cc/type:api-route-lookup api-spec :get "/users/42")
      (expect route :to-be-truthy)
      (expect params :to-equal '((:ID . 42))))
    (expect (cl-cc/type:route-response-type-for api-spec :get "/users/42") :to-be 'user)
    (expect (cl-cc/type:route-response-type-for api-spec :get "/missing") :to-be-null)))

(it-sequential "concrete-utility-type-helpers-operate-on-nats-strings-and-record-transforms"
  (let* ((nat-two (cl-cc/type:make-type-level-natural 2))
         (nat-five (cl-cc/type:type-plus nat-two 3))
         (template (cl-cc/type:template-literal-type "user-" (cl-cc/type:make-type-level-string "id")))
         (record (cl-cc/type:make-type-record :fields (list (cons 'name cl-cc/type:type-string)
                                                            (cons 'age cl-cc/type:type-int))
                                              :row-var nil))
         (partial (cl-cc/type:partial-type record))
         (required (cl-cc/type:required-type partial))
         (frozen (cl-cc/type:freeze "value" cl-cc/type:type-string))
         (matrix-product (cl-cc/type:matrix-mul-type
                          (cl-cc/type:make-matrix-type 2 3 cl-cc/type:type-int)
                          (cl-cc/type:make-matrix-type 3 4 cl-cc/type:type-int)))
         (format-fn (cl-cc/type:format-type "~A => ~D")))
    (expect (cl-cc/type:type-level-natural-value nat-five) :to-equal 5)
    (expect (cl-cc/type:type-level-string-value template) :to-equal "user-id")
    (expect (cl-cc/type:type-union-p (cl-cc/type:get-field-type 'name partial)) :to-be-truthy)
    (expect (cl-cc/type:type-equal-p cl-cc/type:type-string
                                          (cl-cc/type:get-field-type 'name required)) :to-be-truthy)
    (expect (cl-cc/type:frozen-value-p frozen) :to-be-truthy)
    (let ((args (cl-cc/type:type-constructor-args matrix-product)))
      (expect (cl-cc/type:type-level-natural-value (first args)) :to-equal 2)
      (expect (cl-cc/type:type-level-natural-value (second args)) :to-equal 4)
      (expect (cl-cc/type:type-equal-p cl-cc/type:type-int (third args)) :to-be-truthy))
    (expect (cl-cc/type:type-arrow-p format-fn) :to-be-truthy)
    (expect (length (cl-cc/type:type-arrow-params format-fn)) :to-equal 2)))

(it-sequential "region-tokens-enforce-lifetimes"
  (let (dangling)
    (cl-cc/type:with-region (region)
      (setf dangling (cl-cc/type:region-alloc region 42))
      (expect (cl-cc/type:region-ref-valid-p dangling) :to-be-truthy)
      (expect (cl-cc/type:region-deref dangling) :to-equal 42))
    (expect (cl-cc/type:region-ref-valid-p dangling) :to-be-falsy)
    (signals cl-cc/type:region-lifetime-error
        (cl-cc/type:region-deref dangling))))

(it-sequential "capabilities-support-implication-restriction-and-effects"
  (let* ((writer (cl-cc/type:make-capability '(:file-write :network-read)))
         (read-only (cl-cc/type:restrict-capability writer :read-only)))
    (expect (cl-cc/type:capability-allows-p writer :file-read) :to-be-truthy)
    (expect (cl-cc/type:capability-implies-p writer :file-read) :to-be-truthy)
    (expect (cl-cc/type:capability-allows-p read-only :file-write) :to-be-falsy)
    (expect (cl-cc/type:capability-allows-p read-only :file-read) :to-be-truthy)
    (expect (member :READ-FILE (cl-cc/type:capability-effects read-only) :test #'eq) :to-be-truthy)))

(it-sequential "units-of-measure-perform-dimension-checking"
  (let* ((one-meter (cl-cc/type:make-measure 1 'meter))
         (hundred-centimeters (cl-cc/type:make-measure 100 'centimeter))
         (two-seconds (cl-cc/type:make-measure 2 'second))
         (sum (cl-cc/type:measure+ one-meter hundred-centimeters))
         (velocity (cl-cc/type:measure/ (cl-cc/type:make-measure 10 'meter) two-seconds)))
    (expect (cl-cc/type:measure-value sum) :to-equal 2)
    (expect (cl-cc/type:unit-compatible-p (cl-cc/type:measure-unit sum) 'meter) :to-be-truthy)
    (expect (cl-cc/type:convert-unit 100 'centimeter 'meter) :to-equal 1)
    (expect (cl-cc/type:unit-definition-dimension (cl-cc/type:measure-unit velocity))
            :to-equal '((:LENGTH . 1) (:TIME . -1)))
    (signals cl-cc/type:unit-mismatch-error
        (cl-cc/type:measure+ one-meter two-seconds))))

(it-sequential "routing-validates-path-parameters-and-roundtrips"
  (let ((route (cl-cc/type:make-route :get "/users/{id}"
                                      :parameters '((id integer))
                                      :response-type 'user)))
    (expect (cl-cc/type:route-valid-p route) :to-be-truthy)
    (expect (cl-cc/type:build-route-path route '((:id . 42))) :to-equal "/users/42")
    (multiple-value-bind (matched params)
        (cl-cc/type:match-route-path route "/users/42")
      (expect matched :to-be-truthy)
      (expect params :to-equal '((:ID . 42))))
    (signals cl-cc/type:route-validation-error
        (cl-cc/type:build-route-path route '((:id . "forty-two"))))))

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

(it-sequential "qtt-and-graded-semantics-check-semiring-behavior"
  (let* ((semiring (cl-cc/type:make-qtt-semiring))
         (left (cl-cc/type:make-graded-value :one 'x semiring))
         (right (cl-cc/type:make-graded-value :omega 'y semiring))
         (binding (cl-cc/type:make-qtt-binding 'n 'nat 0)))
    (expect (cl-cc/type:valid-multiplicity-p 1) :to-be-truthy)
    (expect (cl-cc/type:valid-multiplicity-p 2) :to-be-falsy)
    (expect (cl-cc/type:multiplicity<= 0 1) :to-be-truthy)
    (expect (cl-cc/type:multiplicity+ 1 :omega) :to-be :omega)
    (expect (cl-cc/type:multiplicity* :omega 1) :to-be :omega)
    (expect (cl-cc/type:usage-satisfies-multiplicity-p 1 1) :to-be-truthy)
    (expect (cl-cc/type:usage-satisfies-multiplicity-p 1 2) :to-be-falsy)
    (expect (cl-cc/type:qtt-erased-p binding) :to-be-truthy)
    (expect (cl-cc/type:finite-semiring-valid-p semiring) :to-be-truthy)
    (expect (cl-cc/type:graded-value-grade (cl-cc/type:graded-add left right)) :to-be :omega)
    (expect (cl-cc/type:graded-value-grade (cl-cc/type:graded-compose left right)) :to-be :omega)))

(it-sequential "cic-scaffolding-validates-universes-and-proof-erasure"
  (let* ((prop (cl-cc/type:make-universe-sort :prop))
         (type0 (cl-cc/type:make-universe-sort :type 0))
         (proposition (cl-cc/type:make-cic-proposition 'non-zero prop '(d)))
         (proof (cl-cc/type:make-cic-proof proposition 'witness)))
    (expect (cl-cc/type:valid-universe-sort-p prop) :to-be-truthy)
    (expect (cl-cc/type:universe<= prop type0) :to-be-truthy)
    (expect (cl-cc/type:cic-large-elimination-allowed-p prop type0) :to-be-falsy)
    (expect (cl-cc/type:cic-proof-valid-p proof) :to-be-truthy)
    (expect (cl-cc/type:proof-erasable-p proof) :to-be-truthy)))

(it-sequential "termination-and-pcc-evidence-check-real-obligations"
  (let* ((termination (cl-cc/type:make-termination-evidence :structural '(5 4 3 2 1)))
         (obligation (cl-cc/type:make-nonzero-obligation 'non-zero-denominator))
         (evidence (cl-cc/type:make-proof-evidence 'non-zero-denominator 2))
         (bundle (cl-cc/type:make-proof-carrying-code 'safe-div (list obligation) (list evidence))))
    (expect (cl-cc/type:termination-evidence-valid-p termination) :to-be-truthy)
    (expect (cl-cc/type:verify-proof-obligation obligation 2) :to-be-truthy)
    (expect (cl-cc/type:verify-proof-evidence obligation evidence) :to-be-truthy)
    (expect (cl-cc/type:verify-proof-carrying-code bundle) :to-be-truthy)
    (expect
     (cl-cc/type:verify-proof-carrying-code
      (cl-cc/type:make-proof-carrying-code
       'unsafe-div
       (list obligation)
       (list (cl-cc/type:make-proof-evidence 'non-zero-denominator 0))))
     :to-be-falsy)))

(it-sequential "advanced-validators-now-use-concrete-semantic-modules"
  (signals error
      (cl-cc/type:parse-type-specifier '(units-of-measure float :unit furlong)))
  (signals error
      (cl-cc/type:parse-type-specifier '(advanced fr-3401 2 fixnum :evidence (proof impossible))))
  (signals error
      (cl-cc/type:parse-type-specifier '(advanced fr-1901 recursive-length :evidence (mystery proof))))
  (let ((route (cl-cc/type:parse-type-specifier '(api-type (get "/users/{id}" integer user)))))
    (expect (cl-cc/type:type-advanced-valid-p route) :to-be-truthy)))

(defun %expect-valid (form expected-id)
  "Parse FORM as a type specifier, assert it is valid and has EXPECTED-ID as its feature id.
Returns the parsed node."
  (let ((node (cl-cc/type:parse-type-specifier form)))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id node) :to-equal expected-id)
    node))

(it-sequential "advanced-contracts-enforce-incremental-staging-optics-and-test-generation"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1606 cache-entry :dependency-graph call-graph)))
  (%expect-valid '(advanced fr-1606 cache-entry :dependency-graph call-graph :cache module-cache :lsp t)
                 "FR-1606")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1703 (code integer) :stage 0 :transition :run)))
  (%expect-valid '(advanced fr-1703 (code integer) :stage 1 :transition :run :evidence (proof staged-eval))
                 "FR-1703")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1801 (zoom a b) :lawful t)))
  (%expect-valid '(advanced fr-1801 (lens a b s t) :lawful t)
                 "FR-1801")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2101 (list integer) :generator fuzz :coverage-target 0)))
  (%expect-valid '(advanced fr-2101 (list integer) :generator (arbitrary integer) :coverage-target 100 :samples 20)
                 "FR-2101"))

(it-sequential "advanced-contracts-enforce-constraint-analysis-and-tooling-families"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2405 user-module :exports (lookup lookup) :fingerprint "")))
  (%expect-valid '(advanced fr-2405 user-module :exports (lookup save) :fingerprint "sha256:abc")
                 "FR-2405")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2406 (< v n) :solver :unknown :theory :lia)))
  (%expect-valid '(advanced fr-2406 (< v n) :solver :z3 :theory :lia :evidence (proof smt-discharge))
                 "FR-2406")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing widen)))
  (%expect-valid '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing narrow)
                 "FR-2804")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2902 (pointer integer) (pointer integer) :disjoint t :alias-class heap)))
  (%expect-valid '(advanced fr-2902 (pointer integer) (pointer float) :disjoint t :alias-class heap)
                 "FR-2902")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-3002 nat-normalise :hook solver :phase :emit)))
  (%expect-valid '(advanced fr-3002 nat-normalise :hook solver :phase :solve)
                 "FR-3002")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 0)))
  (%expect-valid '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 8)
                 "FR-3003"))

(it-sequential "advanced-contracts-enforce-typescript-encodings-effects-and-equality"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(mapped-type (list fixnum) :transform mysterious)))
  (%expect-valid '(mapped-type (list fixnum) :transform optional)
                 "FR-3301")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(conditional-type (list fixnum) :extends list :then item :else item)))
  (%expect-valid '(conditional-type (list fixnum) :extends list :infer item :then item :else null)
                 "FR-3302")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(church-encoding integer :encoding :scott)))
  (%expect-valid '(church-encoding integer :encoding :church)
                 "FR-3403")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(open-union (io io) fixnum)))
  (%expect-valid '(open-union (io state) fixnum)
                 "FR-3404")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(type-theory-equality (-> integer integer) (-> integer integer) :mode :extensional)))
  (%expect-valid '(type-theory-equality (-> integer integer) (-> integer integer)
                                        :mode :extensional
                                        :evidence (proof functional-extensionality))
                 "FR-3405"))

;;; ─── Advanced Call Policy Inference Tests (infer-call boundary validators) ─
;;;
;;; The tests above exercise the *parser* forms for advanced type syntax. These
;;; tests instead drive the *inference-time* call boundary policies registered
;;; in inference-forms-advanced.lisp / -advanced-init.lisp / -advanced-validators.lisp:
;;; each policy is triggered by inferring an AST-CALL node naming a
;;; compiler-facing advanced function (spawn, make-typed-channel, ...).

(defun %mk-advanced-call (function-name &rest arg-forms)
  "Build an AST-CALL node invoking FUNCTION-NAME with ARG-FORMS (already-built AST args)."
  (cl-cc/ast:make-ast-call
   :func (cl-cc/ast:make-ast-var :name function-name)
   :args arg-forms))

(defun %mk-quoted (value)
  "Build an AST-QUOTE node wrapping VALUE (a static/quoted descriptor)."
  (cl-cc/ast:make-ast-quote :value value))

(it-sequential "advanced-call-spawn-enforces-send-boundary"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'spawn (cl-cc/ast:make-ast-int :value 1)))))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2201"))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'spawn (%mk-quoted '(1 2))))))

(it-sequential "advanced-call-shared-ref-enforces-sync-boundary"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'shared-ref (cl-cc/ast:make-ast-int :value 1)))))
    (expect (cl-cc/type:type-equal-p ty cl-cc/type:type-any) :to-be-truthy))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'shared-ref (%mk-quoted '(1 2))))))

(it-sequential "advanced-call-arity-violation-signals-type-inference-error"
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'shared-ref
                           (cl-cc/ast:make-ast-int :value 1)
                           (cl-cc/ast:make-ast-int :value 2)))))

(it-sequential "advanced-call-make-typed-channel-and-buffered-channel"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-typed-channel (%mk-quoted 'fixnum)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2202")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::channel))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-buffered-channel
                                 (%mk-quoted 'fixnum)
                                 (cl-cc/ast:make-ast-int :value 8)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2202")))

(it-sequential "advanced-call-make-actor-ref"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-actor-ref (%mk-quoted 'fixnum)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2203")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::actor-ref)))

(it-sequential "advanced-call-make-tvar"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-tvar
                                 (%mk-quoted 'fixnum)
                                 (cl-cc/ast:make-ast-int :value 0)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2204")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::stm)))

(it-sequential "advanced-call-make-generator-type-and-coroutine-type"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-generator-type (%mk-quoted 'fixnum) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2205")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::generator))
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-coroutine-type
                                 (%mk-quoted 'fixnum) (%mk-quoted 'string) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2205")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::coroutine)))

(it-sequential "advanced-call-make-simd-type"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'make-simd-type
                                 (%mk-quoted 'fixnum)
                                 (cl-cc/ast:make-ast-int :value 4)))))
    (expect (cl-cc/type:type-advanced-feature-id ty) :to-equal "FR-2206")
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'simd-vector)))

(it-sequential "advanced-call-apply-mapped-type-valid-and-invalid-transform"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted 'optional)))))
    (expect (cl-cc/type:type-union-p ty) :to-be-truthy))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'apply-mapped-type (%mk-quoted 'fixnum) (%mk-quoted 'mysterious)))))

(it-sequential "advanced-call-apply-conditional-type-then-and-else-branches"
  (let ((then-ty (cl-cc/type:infer-with-env
                  (%mk-advanced-call 'apply-conditional-type
                                      (%mk-quoted 'fixnum) (%mk-quoted 'fixnum)
                                      (%mk-quoted 'item) (%mk-quoted 'string) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-primitive-p then-ty) :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name then-ty) :to-be 'string))
  (let ((else-ty (cl-cc/type:infer-with-env
                  (%mk-advanced-call 'apply-conditional-type
                                      (%mk-quoted 'fixnum) (%mk-quoted 'symbol)
                                      (%mk-quoted 'item) (%mk-quoted 'string) (%mk-quoted 'null)))))
    (expect (cl-cc/type:type-primitive-p else-ty) :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name else-ty) :to-be 'null)))

(it-sequential "advanced-call-load-type-interface-registers-exports"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'load-type-interface
                                 (%mk-quoted 'advanced-call-test-module)
                                 (%mk-quoted '((exported-test-fn fixnum)))
                                 (%mk-quoted "fingerprint-1")))))
    (expect (cl-cc/type:type-equal-p ty cl-cc/type:type-symbol) :to-be-truthy))
  (multiple-value-bind (scheme found-p)
      (cl-cc/type:lookup-type-interface-export 'exported-test-fn)
    (declare (ignore scheme))
    (expect found-p :to-be-truthy)))

(it-sequential "advanced-call-smt-assert-uses-registered-solver"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'smt-assert
                                 (%mk-quoted '(> x 0))
                                 (%mk-quoted 'z3)
                                 (%mk-quoted 'lia)))))
    (expect (cl-cc/type:type-equal-p ty cl-cc/type:type-bool) :to-be-truthy)))

(it-sequential "advanced-call-run-type-plugin-uses-registered-hook"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'run-type-plugin (%mk-quoted 'nat-normalise) (%mk-quoted 'solve)))))
    (expect (cl-cc/type:type-equal-p ty cl-cc/type:type-any) :to-be-truthy)))

(it-sequential "advanced-call-synthesize-program-uses-registered-strategy"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'synthesize-program
                                 (%mk-quoted '(-> fixnum fixnum))
                                 (%mk-quoted 'enumerative)
                                 (cl-cc/ast:make-ast-int :value 4)))))
    (expect (cl-cc/type:type-arrow-p ty) :to-be-truthy)))

(it-sequential "advanced-call-foreign-call-validates-ffi-descriptor"
  (let ((ty (cl-cc/type:infer-with-env
             (%mk-advanced-call 'foreign-call
                                 (%mk-quoted '(foreign strlen (c-int) c-int))
                                 (cl-cc/ast:make-ast-int :value 3)))))
    (expect (cl-cc/type:type-equal-p ty cl-cc/type:type-int) :to-be-truthy))
  (signals cl-cc/type:type-inference-error
      (cl-cc/type:infer-with-env
       (%mk-advanced-call 'foreign-call
                           (%mk-quoted '(foreign strlen (c-int) c-int))
                           (%mk-quoted "not-an-int")))))

;;; ─── FR-1803 HLists (types-hlist.lisp) ─────────────────────────────────────
;;;
;;; make-hlist-type/hlist-head-type/hlist-tail-type had no direct test
;;; coverage before this addition (they were only mentioned as a symbol in
;;; the evidence-data table, which does not execute them).

(it-sequential "hlist-type-family-builds-heads-tails-and-rejects-non-type-elements"
  (let* ((hlist (cl-cc/type:make-hlist-type
                 (list cl-cc/type:type-int cl-cc/type:type-string cl-cc/type:type-bool)))
         (tail (cl-cc/type:hlist-tail-type hlist))
         (last (cl-cc/type:hlist-tail-type tail)))
    (expect (cl-cc/type:type-advanced-p hlist) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id hlist) :to-equal "FR-1803")
    (expect (cl-cc/type:type-equal-p (cl-cc/type:hlist-head-type hlist) cl-cc/type:type-int)
            :to-be-truthy)
    (expect (cl-cc/type:type-advanced-p tail) :to-be-truthy)
    (expect (cl-cc/type:type-equal-p (cl-cc/type:hlist-head-type tail) cl-cc/type:type-string)
            :to-be-truthy)
    ;; LAST wraps a single remaining element — head-type still works...
    (expect (cl-cc/type:type-equal-p (cl-cc/type:hlist-head-type last) cl-cc/type:type-bool)
            :to-be-truthy)
    ;; ...but taking its tail would build an empty HList, which the FR-1803
    ;; semantic contract (min-args 1) rejects.
    (signals error (cl-cc/type:hlist-tail-type last)))
  (signals error (cl-cc/type:make-hlist-type (list 'not-a-type)))
  (signals error (cl-cc/type:hlist-head-type cl-cc/type:type-int))
  (signals error (cl-cc/type:hlist-tail-type cl-cc/type:type-int)))

;;; ─── make-type-dynamic / make-type-type-rep / payload tree helpers
;;; (types-extended-advanced-init.lisp) — genuinely-callable exported API
;;; that was previously reachable only via a symbol reference inside the
;;; (untested) evidence-data table.

(it-sequential "make-type-dynamic-and-make-type-type-rep-build-valid-fr-2501-and-fr-2502-nodes"
  (let ((dyn (cl-cc/type:make-type-dynamic cl-cc/type:type-int)))
    (expect (cl-cc/type:type-advanced-p dyn) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id dyn) :to-equal "FR-2501")
    (expect (cl-cc/type:type-advanced-valid-p dyn) :to-be-truthy))
  (let ((rep (cl-cc/type:make-type-type-rep cl-cc/type:type-string)))
    (expect (cl-cc/type:type-advanced-p rep) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id rep) :to-equal "FR-2502")
    (expect (cl-cc/type:type-advanced-valid-p rep) :to-be-truthy)))

(it-sequential "advanced-payload-tree-helpers-walk-nested-type-node-structures"
  (let* ((tree (list cl-cc/type:type-int (cons 'wrapped cl-cc/type:type-string) "plain"))
         (children (cl-cc/type::type-advanced-payload-children tree)))
    (expect (= (length children) 2) :to-be-truthy)
    (expect (every (lambda (c) (typep c 'cl-cc/type:type-node)) children) :to-be-truthy))
  (let* ((tree (list cl-cc/type:type-int (cons 'wrapped cl-cc/type:type-string)))
         (mapped (cl-cc/type::type-advanced-payload-map
                  (lambda (ty) (declare (ignore ty)) cl-cc/type:type-bool)
                  tree)))
    (expect (cl-cc/type:type-equal-p (first mapped) cl-cc/type:type-bool) :to-be-truthy)
    (expect (cl-cc/type:type-equal-p (cdr (second mapped)) cl-cc/type:type-bool) :to-be-truthy))
  (expect (cl-cc/type::type-advanced-payload-equal-p
           (list cl-cc/type:type-int "x") (list cl-cc/type:type-int "x"))
          :to-be-truthy)
  (expect (cl-cc/type::type-advanced-payload-equal-p cl-cc/type:type-int "not-a-type-node")
          :to-be-falsy)
  (expect (cl-cc/type::type-advanced-payload-equal-p
           (list cl-cc/type:type-int) (list cl-cc/type:type-string))
          :to-be-falsy)
  (expect (cl-cc/type::type-advanced-properties-equal-p
           '((:a . 1) (:b . 2)) '((:b . 2) (:a . 1)))
          :to-be-truthy)
  (expect (cl-cc/type::type-advanced-properties-equal-p '((:a . 1)) '((:a . 1) (:b . 2)))
          :to-be-falsy))

;;; ─── FR-3303/3304 remaining TS-style utility types (types-utility.lisp) ───

(it-sequential "types-utility-family-covers-writable-deep-readonly-pick-omit-exclude-extract"
  (let* ((record (cl-cc/type:make-type-record
                  :fields (list (cons 'name cl-cc/type:type-string)
                                (cons 'age cl-cc/type:type-int))
                  :row-var nil))
         (writable (cl-cc/type:writable-type cl-cc/type:type-int))
         (deep (cl-cc/type:deep-readonly-type record))
         (picked (cl-cc/type:pick-type record '(name)))
         (omitted (cl-cc/type:omit-type record '(name)))
         (union (cl-cc/type:make-type-union
                 (list cl-cc/type:type-int cl-cc/type:type-string cl-cc/type:type-bool)))
         (excluded (cl-cc/type:exclude-type union cl-cc/type:type-string))
         (extracted (cl-cc/type:extract-type union cl-cc/type:type-int))
         (fn (cl-cc/type:make-type-arrow (list cl-cc/type:type-int) cl-cc/type:type-string)))
    (expect (cl-cc/type:type-capability-p writable) :to-be-truthy)
    (expect (cl-cc/type:type-capability-p deep) :to-be-truthy)
    (expect (= (length (cl-cc/type:type-record-fields picked)) 1) :to-be-truthy)
    (expect (car (first (cl-cc/type:type-record-fields picked))) :to-be 'name)
    (expect (= (length (cl-cc/type:type-record-fields omitted)) 1) :to-be-truthy)
    (expect (car (first (cl-cc/type:type-record-fields omitted))) :to-be 'age)
    (expect (cl-cc/type:type-union-p excluded) :to-be-truthy)
    (expect (cl-cc/type:type-equal-p extracted cl-cc/type:type-int) :to-be-truthy)
    ;; Excluding every member collapses to type-null; extracting nothing does too.
    (expect (cl-cc/type:type-equal-p
             (cl-cc/type:exclude-type (cl-cc/type:make-type-union (list cl-cc/type:type-int))
                                       cl-cc/type:type-int)
             cl-cc/type:type-null)
            :to-be-truthy)
    ;; Non-union exclude/extract go through the plain-type branches.
    (expect (cl-cc/type:type-equal-p
             (cl-cc/type:exclude-type cl-cc/type:type-int cl-cc/type:type-string)
             cl-cc/type:type-int)
            :to-be-truthy)
    (expect (cl-cc/type:type-equal-p
             (cl-cc/type:extract-type cl-cc/type:type-int cl-cc/type:type-int)
             cl-cc/type:type-int)
            :to-be-truthy)
    (expect (cl-cc/type:type-equal-p
             (cl-cc/type:extract-type cl-cc/type:type-int cl-cc/type:type-string)
             cl-cc/type:type-null)
            :to-be-truthy)
    ;; non-nullable-type: direct union and non-union paths.
    (expect (cl-cc/type:type-equal-p
             (cl-cc/type:non-nullable-type
              (cl-cc/type:make-type-union (list cl-cc/type:type-null cl-cc/type:type-int)))
             cl-cc/type:type-int)
            :to-be-truthy)
    (expect (cl-cc/type:type-equal-p (cl-cc/type:non-nullable-type cl-cc/type:type-int)
                                      cl-cc/type:type-int)
            :to-be-truthy)
    (expect (cl-cc/type:type-equal-p (cl-cc/type:return-type-of fn) cl-cc/type:type-string)
            :to-be-truthy)
    (signals error (cl-cc/type:return-type-of cl-cc/type:type-int))
    (signals error (cl-cc/type:pick-type cl-cc/type:type-int '(name)))
    (signals error (cl-cc/type:omit-type cl-cc/type:type-int '(name)))))

;;; ─── Bidirectional checker: Rank-N, mismatch, and skolem escape ───────────
;;; (bidirectional.lisp — check's forall/mismatch branches and the
;;;  skolem-appears-in-type-p / check-skolem-escape helpers were untested.)

(it-sequential "bidirectional-check-against-forall-checks-the-skolemized-body"
  (let* ((env (cl-cc/type:type-env-empty))
         (identity-ast (cl-cc/ast:make-ast-lambda
                        :params '(x)
                        :body (list (cl-cc/ast:make-ast-var :name 'x))))
         (a (cl-cc/type:fresh-type-var :name 'a))
         (expected (cl-cc/type:make-type-forall
                    :var a
                    :body (cl-cc/type:make-type-arrow (list a) a))))
    ;; Must not signal — the identity function checks against (forall a (-> a a)).
    (expect (progn (cl-cc/type:check identity-ast expected env) t) :to-be-truthy)))

(it-sequential "bidirectional-check-signals-type-mismatch-error-on-conflicting-types"
  (let ((env (cl-cc/type:type-env-empty))
        (ast (cl-cc/ast:make-ast-int :value 1)))
    (signals cl-cc/type:type-mismatch-error
        (cl-cc/type:check ast cl-cc/type:type-string env))))

(it-sequential "skolem-appears-in-type-p-covers-every-node-kind"
  (let* ((sk (cl-cc/type:fresh-rigid-var "sk"))
         (other-sk (cl-cc/type:fresh-rigid-var "other"))
         (v (cl-cc/type:fresh-type-var)))
    (expect (cl-cc/type:skolem-appears-in-type-p sk sk) :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p sk other-sk) :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p sk v) :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-arrow (list sk) cl-cc/type:type-int))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-arrow (list cl-cc/type:type-int) sk))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-arrow (list cl-cc/type:type-int) cl-cc/type:type-int))
            :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-forall :var v :body sk))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-constructor 'list (list sk)))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-constructor 'list (list cl-cc/type:type-int)))
            :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-product :elems (list sk)))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p sk cl-cc/type:type-int) :to-be-falsy)))

(it-sequential "check-skolem-escape-signals-only-when-skolem-leaks-into-substitution"
  (let* ((sk (cl-cc/type:fresh-rigid-var "sk"))
         (v (cl-cc/type:fresh-type-var))
         (leaked-subst (cl-cc/type:subst-extend v sk (cl-cc/type:make-substitution)))
         (safe-subst (cl-cc/type:subst-extend v cl-cc/type:type-int (cl-cc/type:make-substitution))))
    (signals cl-cc/type:type-inference-error (cl-cc/type:check-skolem-escape sk leaked-subst))
    (expect (cl-cc/type:check-skolem-escape sk safe-subst) :to-be-null)
    (expect (cl-cc/type:check-skolem-escape sk nil) :to-be-null)))

;;; ─── unparse-type: remaining type-node kinds (printer-unparse.lisp) ───────

(it-sequential "unparse-type-covers-vars-app-forall-intersection-advanced-and-default"
  (expect (cl-cc/type:unparse-type (cl-cc/type:fresh-type-var :name 'x)) :to-be 'x)
  (expect (symbolp (cl-cc/type:unparse-type (cl-cc/type:fresh-type-var))) :to-be-truthy)
  (let ((a (cl-cc/type:fresh-type-var :name 'a)))
    (expect (string= (symbol-name (first (cl-cc/type:unparse-type
                                           (cl-cc/type:make-type-forall :var a :body cl-cc/type:type-int))))
                      "FORALL")
            :to-be-truthy))
  (expect (first (cl-cc/type:unparse-type
                  (cl-cc/type:make-type-intersection (list cl-cc/type:type-int cl-cc/type:type-string))))
          :to-be 'and)
  (expect (first (cl-cc/type:unparse-type
                  (cl-cc/type:make-type-constructor 'list (list cl-cc/type:type-int))))
          :to-be 'list)
  (let ((anon-app (cl-cc/type:make-type-app :fun (cl-cc/type:fresh-type-var) :arg cl-cc/type:type-int)))
    (expect (listp (cl-cc/type:unparse-type anon-app)) :to-be-truthy)
    (expect (= (length (cl-cc/type:unparse-type anon-app)) 2) :to-be-truthy))
  (expect (cl-cc/type:unparse-type :not-a-type-node) :to-be :not-a-type-node)
  ;; type-advanced: registered surface head vs. the generic 'advanced' head.
  (let* ((route-node (cl-cc/type:parse-type-specifier '(api-type (get "/users/{id}" integer user))))
         (route-spec (cl-cc/type:unparse-type route-node)))
    (expect (string= (symbol-name (first route-spec)) "API-TYPE") :to-be-truthy))
  (let* ((generic-node (cl-cc/type:parse-type-specifier
                        '(advanced fr-1606 cache-entry
                          :dependency-graph call-graph :cache module-cache :lsp t)))
         (generic-spec (cl-cc/type:unparse-type generic-node)))
    (expect (string= (symbol-name (first generic-spec)) "ADVANCED") :to-be-truthy)
    (expect (string= (symbol-name (second generic-spec)) "FR-1606") :to-be-truthy)
    (expect (cl-cc/type:type-advanced-valid-p (cl-cc/type:parse-type-specifier generic-spec))
            :to-be-truthy)))

;;; ─── Advanced feature/head registry lookups (types-extended-advanced-meta.lisp) ───

(it-sequential "advanced-feature-registry-listing-and-head-lookup-helpers"
  (let ((ids (cl-cc/type:list-type-advanced-feature-ids))
        (features (cl-cc/type:list-type-advanced-features)))
    (expect (> (length ids) 0) :to-be-truthy)
    (expect (equal ids (sort (copy-list ids) #'string<)) :to-be-truthy)
    (expect (= (length ids) (length features)) :to-be-truthy)
    (expect (member "FR-1803" ids :test #'string=) :to-be-truthy))
  (expect (cl-cc/type:type-advanced-feature-id-for-head 'qtt) :to-equal "FR-3401")
  (expect (cl-cc/type:type-advanced-feature-id-for-head "QTT") :to-equal "FR-3401")
  (expect (cl-cc/type:type-advanced-feature-id-for-head 'not-a-registered-head) :to-be-null)
  (expect (cl-cc/type:type-advanced-head-p 'qtt) :to-be-truthy)
  (expect (cl-cc/type:type-advanced-head-p 'advanced) :to-be-truthy)
  (expect (cl-cc/type:type-advanced-head-p 'not-a-registered-head) :to-be-falsy)
  (expect (cl-cc/type:type-advanced-head-p 42) :to-be-falsy)
  (signals error (cl-cc/type:canonicalize-type-advanced-feature-id 42)))

;;; ─── Advanced contract registry error paths (types-extended-advanced-contract.lisp) ───
;;; Contract construction/registration are internal (not exported) — accessed
;;; the same way this file already reaches other internal structs
;;; (cl-cc/type::%make-stm-action, cl-cc/type::make-api-spec above).

(it-sequential "advanced-contract-registry-rejects-invalid-specs-duplicates-and-unknown-features"
  (expect (cl-cc/type::lookup-type-advanced-contract "FR-9999-NOT-A-FEATURE") :to-be-null)
  (signals error
      (cl-cc/type::make-type-advanced-contract :id "FR-1501" :semantic-domain nil :min-args 1))
  (signals error
      (cl-cc/type::make-type-advanced-contract :id "FR-1501" :semantic-domain :safety))
  (let ((contract (cl-cc/type::make-type-advanced-contract
                    :id "FR-1501" :semantic-domain :safety :min-args 1)))
    (expect (cl-cc/type::type-advanced-contract-p contract) :to-be-truthy)
    (expect (cl-cc/type::type-advanced-contract-feature-id contract) :to-equal "FR-1501")
    (signals error (cl-cc/type::register-type-advanced-contract contract))
    (signals error
        (cl-cc/type::register-type-advanced-contract
         (cl-cc/type::make-type-advanced-contract
          :id "FR-UNKNOWN-FEATURE" :semantic-domain :safety :min-args 1)))))

;;; ─── Advanced node property/security-label/route accessors (types-extended-advanced-node.lisp) ───

(it-sequential "advanced-node-property-accessors-security-label-and-route-predicate"
  (let ((node (cl-cc/type:parse-type-specifier
               '(advanced fr-1606 cache-entry
                 :dependency-graph call-graph :cache module-cache :lsp t))))
    (expect (cl-cc/type:type-advanced-property-present-p node :cache) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-property-present-p node :missing-property) :to-be-falsy)
    (expect (cl-cc/type:type-advanced-property node :missing-property :fallback) :to-be :fallback))
  (expect (cl-cc/type:type-advanced-security-label<= :public :secret) :to-be-truthy)
  (expect (cl-cc/type:type-advanced-security-label<= :secret :public) :to-be-falsy)
  (expect (cl-cc/type:type-advanced-route-p
           (cl-cc/type:make-route :get "/x" :parameters nil :response-type 'y))
          :to-be-truthy)
  (expect (cl-cc/type:type-advanced-route-p 42) :to-be-falsy))

;;; ─── QTT/graded keyword surface normalization (types-extended-advanced-node.lisp) ───
;;; %type-advanced-normalize-graded-keyword-arg turns the (qtt/graded :GRADE value)
;;; keyword-shaped surface (misparsed as a property by the generic advanced-form
;;; parser) back into two positional args before validation.

(it-sequential "qtt-and-graded-keyword-surface-normalizes-to-positional-multiplicity-args"
  (let* ((node (cl-cc/type:parse-type-specifier '(graded :omega x))))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id node) :to-equal "FR-3402")
    (expect (= (length (cl-cc/type:type-advanced-args node)) 2) :to-be-truthy))
  (signals error (cl-cc/type:parse-type-specifier '(graded :grade x))))

;;; ─── Implementation-evidence completeness helpers (types-extended-advanced-validate.lisp) ───
;;; NOTE: in this standalone cl-cc-type checkout, type-advanced-semantics-implemented-p
;;; currently always returns NIL for every feature id: the evidence module paths in
;;; types-extended-advanced-evidence-data.lisp still reference the pre-extraction
;;; "packages/type/src/..." monorepo layout (relative to a now-nonexistent :cl-cc ASDF
;;; system — see %type-advanced-implementation-module-present-p), so no evidence module
;;; ever resolves. These assertions pin the current (buggy) behavior as a regression
;;; test; see the coverage-pass report for a flagged follow-up to fix the paths.

(it-sequential "type-advanced-semantics-implemented-p-reflects-current-evidence-availability"
  ;; FR-1501's module/API/test-anchor evidence resolves correctly against this
  ;; standalone checkout (src/... paths under the :cl-cc-type system), so it
  ;; reports implemented. An unknown feature id is never implemented.
  (expect (cl-cc/type:type-advanced-semantics-implemented-p "FR-1501") :to-be-truthy)
  (expect (cl-cc/type:type-advanced-semantics-implemented-p "FR-9999-NOT-A-FEATURE") :to-be-null)
  (expect (cl-cc/type::%type-advanced-implementation-api-available-p 'cl-cc/type:make-hlist-type)
          :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-implementation-api-available-p 'cl-cc/type::totally-unbound-fn-xyz)
          :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-api-available-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-module-present-p "src/types-hlist.lisp")
          :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-implementation-module-present-p
           "packages/type/src/types-extended-nodes.lisp")
          :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-module-present-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-implementation-test-anchor-available-p 42) :to-be-falsy))
