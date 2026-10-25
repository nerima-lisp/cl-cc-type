;;;; t/types-extended-qtt-test.lisp — QTT and Graded Types Tests
;;;;
;;;; Tests for src/types-extended-qtt.lisp:
;;;; QTT semiring multiplicity operations and graded-value semiring behavior.

(in-package #:cl-cc/type/quantities/test)

(it-sequential "qtt-and-graded-semantics-check-semiring-behavior"
  (let* ((semiring (make-qtt-semiring))
         (left (make-graded-value :one 'x semiring))
         (right (make-graded-value :omega 'y semiring))
         (binding (make-qtt-binding 'n 'nat 0)))
    (expect (valid-multiplicity-p 1) :to-be-truthy)
    (expect (valid-multiplicity-p 2) :to-be-falsy)
    (expect (multiplicity<= 0 1) :to-be-truthy)
    (expect (multiplicity+ 1 :omega) :to-be :omega)
    (expect (multiplicity* :omega 1) :to-be :omega)
    (expect (usage-satisfies-multiplicity-p 1 1) :to-be-truthy)
    (expect (usage-satisfies-multiplicity-p 1 2) :to-be-falsy)
    (expect (multiplicity-one-p 1) :to-be-truthy)
    (expect (multiplicity-one-p 0) :to-be-falsy)
    (expect (multiplicity-unrestricted-p :omega) :to-be-truthy)
    (expect (multiplicity-unrestricted-p 1) :to-be-falsy)
    (expect (qtt-erased-p binding) :to-be-truthy)
    (expect (finite-semiring-valid-p semiring) :to-be-truthy)
    (expect (graded-value-grade (graded-add left right)) :to-be :omega)
    (expect (graded-value-grade (graded-compose left right)) :to-be :omega)))

(it-sequential "usage-satisfies-multiplicity-p-covers-every-declared-grade-and-a-negative-count"
  ;; The pre-existing test only ever drove DECLARED = :one; the :zero and
  ;; :omega arms of the inner CASE, and the (not (minusp actual-uses))
  ;; guard's true-for-a-negative-count outcome, were never exercised.
  (expect (usage-satisfies-multiplicity-p :zero 0) :to-be-truthy)
  (expect (usage-satisfies-multiplicity-p :zero 1) :to-be-falsy)
  (expect (usage-satisfies-multiplicity-p :omega 5) :to-be-truthy)
  (expect (usage-satisfies-multiplicity-p 1 -1) :to-be-falsy))

(it-sequential "grade-designator-p-accepts-multiplicities-and-natural-numbers-only"
  (expect (grade-designator-p :one) :to-be-truthy)
  (expect (grade-designator-p 5) :to-be-truthy)
  (expect (grade-designator-p -1) :to-be-falsy)
  (expect (grade-designator-p "not-a-grade") :to-be-falsy))

(it-sequential "make-graded-value-rejects-a-grade-outside-the-semiring-carrier"
  (signals error
      (make-graded-value :not-a-qtt-grade 'x (make-qtt-semiring))))

(it-sequential "graded-add-and-graded-compose-reject-mismatched-semirings"
  ;; MAKE-QTT-SEMIRING builds a fresh, non-EQ FINITE-SEMIRING struct on
  ;; every call, so two structurally-identical calls are enough to trigger
  ;; the "different semirings" guard in both functions.
  (let ((left (make-graded-value :one 'x (make-qtt-semiring)))
        (right (make-graded-value :one 'y (make-qtt-semiring))))
    (signals error
        (graded-add left right))
    (signals error
        (graded-compose left right))))

(it-sequential "qtt-erased-p-is-falsy-for-a-non-qtt-binding-value"
  (expect (qtt-erased-p "not-a-binding") :to-be-falsy))

(it-sequential "finite-semiring-valid-p-rejects-a-semiring-missing-an-identity-element"
  ;; %semiring-has-identities-p is the first check in the AND chain; the
  ;; pre-existing test only ever calls FINITE-SEMIRING-VALID-P on the
  ;; correctly-built QTT semiring, so its false branch (and everything
  ;; after it in the chain) was never exercised.
  (expect (finite-semiring-valid-p
           (make-finite-semiring
            :name :broken :elements '(:zero :one) :zero :missing-from-elements
            :one :one :add #'multiplicity+ :multiply #'multiplicity*
            :preorder #'multiplicity<=))
          :to-be-falsy))

(it-sequential "finite-semiring-valid-p-rejects-a-semiring-whose-add-violates-the-identity-law"
  ;; Identities are present (so %semiring-has-identities-p passes), but ADD
  ;; ignores its arguments, so a+0=a fails for :one -- exercising
  ;; %semiring-per-element-laws-p's false branch specifically.
  (expect (finite-semiring-valid-p
           (make-finite-semiring
            :name :broken :elements '(:zero :one) :zero :zero :one :one
            :add (lambda (a b) (declare (ignore a b)) :zero)
            :multiply #'multiplicity*
            :preorder #'multiplicity<=))
          :to-be-falsy))

(it-sequential "finite-semiring-valid-p-rejects-a-semiring-whose-multiply-violates-the-identity-law"
  ;; The mirror image of the ADD-identity-law test above: MULTIPLY here
  ;; ignores its arguments and always returns :ZERO, so mult(a,1) and
  ;; mult(1,a) both stay within ELEMENTS (member passes: :ZERO is a member)
  ;; but a*1=a fails for :ONE -- isolating %semiring-per-element-laws-p's
  ;; multiplicative-identity equal check specifically.
  (expect (finite-semiring-valid-p
           (make-finite-semiring
            :name :broken :elements '(:zero :one :omega) :zero :zero :one :one
            :add #'multiplicity+
            :multiply (lambda (a b) (declare (ignore a b)) :zero)
            :preorder #'multiplicity<=))
          :to-be-falsy))

(it-sequential "finite-semiring-valid-p-rejects-a-non-reflexive-preorder"
  ;; ADD/MULTIPLY/ZERO/ONE are the real, already-valid QTT operators, so
  ;; every earlier AND clause passes and %semiring-preorder-valid-p's own
  ;; false branch (via a preorder that is never reflexive) is what fails.
  (expect (finite-semiring-valid-p
           (make-finite-semiring
            :name :broken :elements '(:zero :one :omega) :zero :zero :one :one
            :add #'multiplicity+ :multiply #'multiplicity*
            :preorder (lambda (a b) (declare (ignore a b)) nil)))
          :to-be-falsy))

(it-sequential "finite-semiring-valid-p-rejects-a-reflexive-but-non-transitive-preorder"
  ;; %semiring-preorder-valid-p's reflexivity clause and its transitivity
  ;; clause are two independent conjuncts; the non-reflexive-preorder case
  ;; above only ever drives the first one false. A preorder that is
  ;; reflexive but relates :zero < :one < :omega without ever relating
  ;; :zero to :omega directly is reflexive (every A relates to itself) yet
  ;; violates transitivity for exactly that triple, isolating the second
  ;; conjunct's own false branch.
  (expect (finite-semiring-valid-p
           (make-finite-semiring
            :name :broken :elements '(:zero :one :omega) :zero :zero :one :one
            :add #'multiplicity+ :multiply #'multiplicity*
            :preorder (lambda (a b)
                        (or (eq a b)
                            (and (eq a :zero) (eq b :one))
                            (and (eq a :one) (eq b :omega))))))
          :to-be-falsy))

(it-sequential "finite-semiring-valid-p-rejects-a-non-commutative-add"
  ;; %semiring-commutative-p's false branch had never been exercised:
  ;; every prior semiring either fully satisfied it (the real QTT
  ;; semiring) or already failed an earlier AND clause. A 2-element
  ;; carrier can't break commutativity without also breaking an identity
  ;; law (every pair involves ZERO), so this needs a 3rd element: ADD
  ;; matches ordinary mod-3 addition everywhere except the ordered pair
  ;; (1, 2), which is swapped from what commutativity would require —
  ;; identities and per-element laws (which only ever call ADD/MULTIPLY
  ;; against ZERO/ONE) never touch that pair, so this isolates
  ;; %semiring-commutative-p's own comparison.
  (let ((Add (lambda (a b)
               (cond ((and (= a 1) (= b 2)) 0)
                     ((and (= a 2) (= b 1)) 1)
                     (t (mod (+ a b) 3)))))
        (multiply (lambda (a b)
                    (cond ((or (= a 0) (= b 0)) 0)
                          ((= a 1) b)
                          ((= b 1) a)
                          (t (mod (* a b) 3))))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1 2) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-a-non-associative-add"
  ;; %semiring-associative-distributive-p's false branch had never been
  ;; exercised either. This ADD is fully commutative and closed (so
  ;; %semiring-commutative-p passes) and matches ordinary mod-3 addition
  ;; everywhere except the symmetric input (1, 1), which is overridden to
  ;; 0 -- (1+1)+2 = 0+2 = 2 but 1+(1+2) = 1+0 = 1, breaking associativity
  ;; while every pairwise identity/commutativity check still holds.
  (let ((Add (lambda (a b)
               (if (and (= a 1) (= b 1)) 0 (mod (+ a b) 3))))
        (multiply (lambda (a b)
                    (cond ((or (= a 0) (= b 0)) 0)
                          ((= a 1) b)
                          ((= b 1) a)
                          (t (mod (* a b) 3))))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1 2) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-an-add-that-is-not-closed-over-elements"
  ;; %semiring-per-element-laws-p's MEMBER checks -- (MEMBER (FUNCALL ADD
  ;; a ZERO) ELEMENTS), etc. -- had only ever been observed true: every
  ;; broken semiring above breaks a LAW (identity, commutativity,
  ;; associativity) while staying closed over ELEMENTS. This ADD returns
  ;; a value entirely outside ELEMENTS for one specific pair (1, 0), but
  ;; is ordinary addition everywhere else, so element 0 still passes
  ;; every one of its own checks before ELEMENT 1's own closure check
  ;; fails immediately.
  (let ((Add (lambda (a b) (if (and (= a 1) (= b 0)) 99 (+ a b))))
        (multiply (lambda (a b) (* a b))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-a-multiply-that-is-not-closed-over-elements"
  ;; Mirrors the ADD case above for MULTIPLY's own closure conjuncts,
  ;; (MEMBER (FUNCALL MULTIPLY a ONE) ELEMENTS) and its ONE-a mirror.
  ;; ADD here is ordinary and fully valid, so the AND reaches MULTIPLY's
  ;; checks for every element before ever failing.
  (let ((Add (lambda (a b) (+ a b)))
        (multiply (lambda (a b) (if (and (= a 1) (= b 1)) 99 (* a b)))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

;;; ─── %semiring-per-element-laws-p: the ZERO-a / ONE-a argument orders ──────
;;;
;;; Every broken-semiring case above overrides ADD/MULTIPLY only for an
;;; a-FIRST pair (A, ZERO) or (A, ONE); each test's ADD/MULTIPLY is fully
;;; symmetric everywhere else, so the "commuted" ZERO-a / ONE-a conjuncts
;;; below always inherited the SAME (already-true) outcome as their
;;; a-first sibling. Overriding a ZERO-first or ONE-first pair instead
;;; isolates each commuted conjunct on its own, at element A = 1 (member
;;; break) or A = 0 (all four remaining cases), the first element checked
;;; that reaches each specific conjunct.

(it-sequential "finite-semiring-valid-p-rejects-an-add-whose-zero-a-order-is-not-closed"
  (let ((Add (lambda (a b) (if (and (= a 0) (= b 1)) 99 (+ a b))))
        (multiply (lambda (a b) (* a b))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-an-add-whose-zero-a-order-violates-the-identity-law"
  (let ((Add (lambda (a b) (if (and (= a 0) (= b 1)) 0 (+ a b))))
        (multiply (lambda (a b) (* a b))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-a-multiply-whose-one-a-order-is-not-closed"
  (let ((Add (lambda (a b) (+ a b)))
        (multiply (lambda (a b) (if (and (= a 1) (= b 0)) 99 (* a b)))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-a-multiply-whose-one-a-order-violates-the-identity-law"
  (let ((Add (lambda (a b) (+ a b)))
        (multiply (lambda (a b) (if (and (= a 1) (= b 0)) 1 (* a b)))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-an-add-that-is-not-closed-for-a-non-identity-pair"
  ;; %semiring-commutative-p's own ADD closure conjunct, (MEMBER (FUNCALL
  ;; ADD a b) ELEMENTS), had only ever been observed true: the earlier
  ;; ADD-not-closed case above breaks closure at a ZERO-involving pair,
  ;; which %semiring-per-element-laws-p already rejects before
  ;; commutative-p is ever reached. A 3rd, non-identity element (2) lets
  ;; ADD break closure specifically for (1, 2) without touching any
  ;; ZERO/ONE identity pair.
  (let ((Add (lambda (a b) (if (and (= a 1) (= b 2)) 99 (mod (+ a b) 3))))
        (multiply (lambda (a b) (cond ((or (= a 0) (= b 0)) 0)
                                      ((= a 1) b)
                                      ((= b 1) a)
                                      (t (mod (* a b) 3))))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1 2) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

(it-sequential "finite-semiring-valid-p-rejects-a-non-associative-multiply"
  ;; %semiring-associative-distributive-p's own MULTIPLY-associativity
  ;; conjunct (distinct from the ADD-associativity case already tested
  ;; above) had never been exercised. ADD is ordinary mod-4 addition
  ;; (fully valid); MULTIPLY forces the required ZERO-annihilation and
  ;; ONE-identity laws for every element, leaving only the (2, 2), (2, 3)
  ;; and (3, 3) products free -- chosen so (2 * 2) * 3 = 1 * 3 = 3 but
  ;; 2 * (2 * 3) = 2 * 0 = 0, breaking associativity for that one triple
  ;; while every element's own identity/annihilation laws, and full
  ;; pairwise closure/commutativity, still hold.
  (let ((Add (lambda (a b) (mod (+ a b) 4)))
        (multiply (lambda (a b)
                    (cond ((or (= a 0) (= b 0)) 0)
                          ((= a 1) b)
                          ((= b 1) a)
                          ((and (= a 2) (= b 2)) 1)
                          ((or (and (= a 2) (= b 3)) (and (= a 3) (= b 2))) 0)
                          ((and (= a 3) (= b 3)) 1)
                          (t (error "unexpected pair ~S ~S" a b))))))
    (expect (finite-semiring-valid-p
             (make-finite-semiring
              :name :broken :elements '(0 1 2 3) :zero 0 :one 1
              :add Add :multiply multiply :preorder (constantly t)))
            :to-be-falsy)))

