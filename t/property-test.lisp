;;;; t/property-test.lisp — Property-based and fuzz tests (cl-weave it-property/it-fuzz)
;;;;
;;;; Algebraic invariants of the type system, checked against generated inputs
;;;; rather than hand-picked examples: type-equal-p/is-subtype-p reflexivity
;;;; over parsed primitives, QTT multiplicity-semiring commutativity, and a
;;;; fuzz check that parse-type-specifier never signals on an arbitrary symbol.

(in-package :cl-cc-type/test)

(it-property "type-equal-p is reflexive for any parsed primitive symbol"
    ((name (gen-member '(fixnum integer string boolean bool symbol character
                         char t top cons nil))))
  (let ((ty (parse-type-specifier name)))
    (expect ty :to-be-type-equal-to ty)))

(it-property "is-subtype-p is reflexive for any parsed primitive symbol"
    ((name (gen-member '(fixnum integer string boolean bool symbol character
                         char t top cons nil))))
  (let ((ty (parse-type-specifier name)))
    (expect (is-subtype-p ty ty) :to-be-truthy)))

(it-fuzz "parse-type-specifier never signals on an arbitrary symbol"
    ((name (gen-symbol :names '("alpha" "beta" "gamma" "delta" "epsilon"
                                "zeta" "eta" "theta")
                       :package "CL-CC-TYPE/TEST")))
    (:trials 50)
  (parse-type-specifier name))

(it-fuzz "parse-type-specifier never signals an unexpected condition on arbitrary nested s-expressions"
    ((form (gen-sexp :max-depth 4 :max-list-length 4)))
    (:trials 200)
  ;; TYPE-PARSE-ERROR (and every other condition this package signals) is the
  ;; correct, documented response to malformed input -- rejecting it is what
  ;; PARSE-TYPE-SPECIFIER is FOR, not a crash. Catching the package's own
  ;; TYPE-SYSTEM-ERROR base condition here lets the trial pass on that
  ;; expected outcome; anything else escaping (an unbound variable, a raw
  ;; CL TYPE-ERROR from destructuring malformed input, unbounded recursion)
  ;; is the real "never crashes" property this fuzz check exists to test.
  (handler-case (parse-type-specifier form)
    (type-system-error () nil)))

(it-property "multiplicity+ is commutative over the QTT semiring"
    ((left (gen-member '(0 1 :omega)))
     (right (gen-member '(0 1 :omega))))
  (expect (multiplicity+ left right) :to-be (multiplicity+ right left)))

(it-property "multiplicity* is commutative over the QTT semiring"
    ((left (gen-member '(0 1 :omega)))
     (right (gen-member '(0 1 :omega))))
  (expect (multiplicity* left right) :to-be (multiplicity* right left)))

(it-property "normalize-multiplicity is idempotent"
    ((value (gen-member '(0 1 :omega :zero :one :ω omega unrestricted))))
  (let ((normalized (normalize-multiplicity value)))
    (expect (normalize-multiplicity normalized) :to-be normalized)))
