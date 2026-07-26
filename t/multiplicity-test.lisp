;;;; t/multiplicity-test.lisp — Multiplicity System Tests
;;;;
;;;; Tests for src/multiplicity.lisp:
;;;; multiplicity-p, mult-add (semiring join), mult-mul (semiring scale),
;;;; mult-leq (ordering), mult-to-string.

(in-package :cl-cc-type/test)

;;; ─── multiplicity-p ─────────────────────────────────────────────────────────

(progn
  (it-sequential "mult-valid-grades zero"
    (expect (multiplicity-p :zero) :to-be-truthy))
  (it-sequential "mult-valid-grades one"
    (expect (multiplicity-p :one) :to-be-truthy))
  (it-sequential "mult-valid-grades omega"
    (expect (multiplicity-p :omega) :to-be-truthy)))

(progn
  (it-sequential "mult-invalid-grades nil"
    (expect (multiplicity-p nil) :to-be-falsy))
  (it-sequential "mult-invalid-grades integer"
    (expect (multiplicity-p 0) :to-be-falsy))
  (it-sequential "mult-invalid-grades string"
    (expect (multiplicity-p "one") :to-be-falsy))
  (it-sequential "mult-invalid-grades keyword"
    (expect (multiplicity-p :two) :to-be-falsy)))

;;; ─── mult-add (semiring join) ───────────────────────────────────────────────

(progn
  (it-sequential "mult-add-identity zero-left"
    (expect (mult-add :zero :zero) :to-be :zero))
  (it-sequential "mult-add-identity one-left"
    (expect (mult-add :one :zero) :to-be :one))
  (it-sequential "mult-add-identity omega-left"
    (expect (mult-add :omega :zero) :to-be :omega))
  (it-sequential "mult-add-identity zero-right"
    (expect (mult-add :zero :zero) :to-be :zero))
  (it-sequential "mult-add-identity one-right"
    (expect (mult-add :zero :one) :to-be :one))
  (it-sequential "mult-add-identity omega-right"
    (expect (mult-add :zero :omega) :to-be :omega)))

(progn
  (it-sequential "mult-add-idempotent zero"
    (expect (mult-add :zero :zero) :to-be :zero))
  (it-sequential "mult-add-idempotent one"
    (expect (mult-add :one :one) :to-be :one))
  (it-sequential "mult-add-idempotent omega"
    (expect (mult-add :omega :omega) :to-be :omega)))

(it-sequential "mult-add-one-omega"
  (expect (mult-add :one :omega) :to-be :omega)
  (expect (mult-add :omega :one) :to-be :omega))

;;; ─── mult-mul (semiring scale) ──────────────────────────────────────────────

(progn
  (it-sequential "mult-mul-zero-absorbs zero-zero"
    (expect (mult-mul :zero :zero) :to-be :zero))
  (it-sequential "mult-mul-zero-absorbs zero-one"
    (expect (mult-mul :zero :one) :to-be :zero))
  (it-sequential "mult-mul-zero-absorbs zero-omega"
    (expect (mult-mul :zero :omega) :to-be :zero))
  (it-sequential "mult-mul-zero-absorbs one-zero"
    (expect (mult-mul :one :zero) :to-be :zero))
  (it-sequential "mult-mul-zero-absorbs omega-zero"
    (expect (mult-mul :omega :zero) :to-be :zero)))

(progn
  (it-sequential "mult-mul-one-identity one-one"
    (expect (mult-mul :one :one) :to-be :one))
  (it-sequential "mult-mul-one-identity one-omega"
    (expect (mult-mul :one :omega) :to-be :omega))
  (it-sequential "mult-mul-one-identity omega-one"
    (expect (mult-mul :omega :one) :to-be :omega)))

(it-sequential "mult-mul-omega-omega"
  (expect (mult-mul :omega :omega) :to-be :omega))

;;; ─── mult-leq (ordering) ────────────────────────────────────────────────────

(progn
  (it-sequential "mult-leq-reflexive zero"
    (expect (mult-leq :zero :zero) :to-be-truthy))
  (it-sequential "mult-leq-reflexive one"
    (expect (mult-leq :one :one) :to-be-truthy))
  (it-sequential "mult-leq-reflexive omega"
    (expect (mult-leq :omega :omega) :to-be-truthy)))

(progn
  (it-sequential "mult-leq-zero-bottom zero-one"
    (expect (mult-leq :zero :one) :to-be-truthy))
  (it-sequential "mult-leq-zero-bottom zero-omega"
    (expect (mult-leq :zero :omega) :to-be-truthy)))

(progn
  (it-sequential "mult-leq-omega-top zero-omega"
    (expect (mult-leq :zero :omega) :to-be-truthy))
  (it-sequential "mult-leq-omega-top one-omega"
    (expect (mult-leq :one :omega) :to-be-truthy)))

(progn
  (it-sequential "mult-leq-false-cases one-not-leq-zero"
    (expect (mult-leq :one :zero) :to-be-falsy))
  (it-sequential "mult-leq-false-cases omega-not-leq-one"
    (expect (mult-leq :omega :one) :to-be-falsy)))

;;; ─── mult-to-string ─────────────────────────────────────────────────────────

(progn
  (it-sequential "mult-to-string-values zero"
    (expect (mult-to-string :zero) :to-equal "0"))
  (it-sequential "mult-to-string-values one"
    (expect (mult-to-string :one) :to-equal "1"))
  (it-sequential "mult-to-string-values omega"
    (expect (mult-to-string :omega) :to-equal "ω")))

(progn
  (it-sequential "multiplicity-p-recognition zero-valid"
    (expect (cl-cc/type:multiplicity-p :zero) :to-be-truthy))
  (it-sequential "multiplicity-p-recognition one-valid"
    (expect (cl-cc/type:multiplicity-p :one) :to-be-truthy))
  (it-sequential "multiplicity-p-recognition omega-valid"
    (expect (cl-cc/type:multiplicity-p :omega) :to-be-truthy))
  (it-sequential "multiplicity-p-recognition two-invalid"
    (expect (cl-cc/type:multiplicity-p :two) :to-be-falsy))
  (it-sequential "multiplicity-p-recognition nil-invalid"
    (expect (cl-cc/type:multiplicity-p nil) :to-be-falsy))
  (it-sequential "multiplicity-p-recognition int-invalid"
    (expect (cl-cc/type:multiplicity-p 1) :to-be-falsy)))

(progn
  (it-sequential "multiplicity-grade-constants zero"
    (expect (multiplicity-p +mult-zero+) :to-be-truthy)
    (expect +mult-zero+ :to-be :zero))
  (it-sequential "multiplicity-grade-constants one"
    (expect (multiplicity-p +mult-one+) :to-be-truthy)
    (expect +mult-one+ :to-be :one))
  (it-sequential "multiplicity-grade-constants omega"
    (expect (multiplicity-p +mult-omega+) :to-be-truthy)
    (expect +mult-omega+ :to-be :omega)))

(progn
  (it-sequential "multiplicity-add 0+0=0"
    (expect (mult-add :zero :zero) :to-be :zero))
  (it-sequential "multiplicity-add 0+1=1"
    (expect (mult-add :zero :one) :to-be :one))
  (it-sequential "multiplicity-add 1+0=1"
    (expect (mult-add :one :zero) :to-be :one))
  (it-sequential "multiplicity-add 0+ω=ω"
    (expect (mult-add :zero :omega) :to-be :omega))
  (it-sequential "multiplicity-add 1+1=1"
    (expect (mult-add :one :one) :to-be :one))
  (it-sequential "multiplicity-add 1+ω=ω"
    (expect (mult-add :one :omega) :to-be :omega))
  (it-sequential "multiplicity-add ω+ω=ω"
    (expect (mult-add :omega :omega) :to-be :omega)))

(progn
  (it-sequential "multiplicity-mul 0*0=0"
    (expect (mult-mul :zero :zero) :to-be :zero))
  (it-sequential "multiplicity-mul 0*1=0"
    (expect (mult-mul :zero :one) :to-be :zero))
  (it-sequential "multiplicity-mul 0*ω=0"
    (expect (mult-mul :zero :omega) :to-be :zero))
  (it-sequential "multiplicity-mul 1*0=0"
    (expect (mult-mul :one :zero) :to-be :zero))
  (it-sequential "multiplicity-mul 1*1=1"
    (expect (mult-mul :one :one) :to-be :one))
  (it-sequential "multiplicity-mul 1*ω=ω"
    (expect (mult-mul :one :omega) :to-be :omega))
  (it-sequential "multiplicity-mul ω*0=0"
    (expect (mult-mul :omega :zero) :to-be :zero))
  (it-sequential "multiplicity-mul ω*1=ω"
    (expect (mult-mul :omega :one) :to-be :omega))
  (it-sequential "multiplicity-mul ω*ω=ω"
    (expect (mult-mul :omega :omega) :to-be :omega)))

(progn
  (it-sequential "multiplicity-leq 0≤0"
    (expect (mult-leq :zero :zero) :to-be-truthy))
  (it-sequential "multiplicity-leq 0≤1"
    (expect (mult-leq :zero :one) :to-be-truthy))
  (it-sequential "multiplicity-leq 0≤ω"
    (expect (mult-leq :zero :omega) :to-be-truthy))
  (it-sequential "multiplicity-leq 1≤1"
    (expect (mult-leq :one :one) :to-be-truthy))
  (it-sequential "multiplicity-leq 1≤ω"
    (expect (mult-leq :one :omega) :to-be-truthy))
  (it-sequential "multiplicity-leq ω≤ω"
    (expect (mult-leq :omega :omega) :to-be-truthy))
  (it-sequential "multiplicity-leq 1≰0"
    (expect (mult-leq :one :zero) :to-be-falsy))
  (it-sequential "multiplicity-leq ω≰1"
    (expect (mult-leq :omega :one) :to-be-falsy))
  (it-sequential "multiplicity-leq ω≰0"
    (expect (mult-leq :omega :zero) :to-be-falsy)))

(progn
  (it-sequential "multiplicity-to-string zero"
    (expect (mult-to-string :zero) :to-equal "0"))
  (it-sequential "multiplicity-to-string one"
    (expect (mult-to-string :one) :to-equal "1"))
  (it-sequential "multiplicity-to-string omega"
    (expect (mult-to-string :omega) :to-equal "ω")))

;;; ─── Semiring laws (property-based) ─────────────────────────────────────────
;;;
;;; The multiplicity domain {:zero :one :omega} is a small finite semiring
;;; under mult-add/mult-mul, and totally ordered under mult-leq. Rather than
;;; hand-enumerate the 3, 9, and 27 cases these laws range over, generate both
;;; (or all three) operands from the domain and assert the algebraic law
;;; directly. Each law below was verified against src/multiplicity.lisp by
;;; exhaustively checking all combinations before being written as a test:
;;;   - mult-add is exactly max under the mult-leq total order zero<one<omega,
;;;     so it is commutative and associative.
;;;   - mult-mul distributes over mult-add (a genuine semiring law here).
;;;   - mult-leq is reflexive by construction (its first disjunct is (eq q1 q2)).

(it-property "mult-add-commutative"
    ((a (gen-member '(:zero :one :omega)))
     (b (gen-member '(:zero :one :omega))))
  (expect (mult-add a b) :to-be (mult-add b a)))

(it-property "mult-add-associative"
    ((a (gen-member '(:zero :one :omega)))
     (b (gen-member '(:zero :one :omega)))
     (c (gen-member '(:zero :one :omega))))
  (expect (mult-add (mult-add a b) c) :to-be (mult-add a (mult-add b c))))

(it-property "mult-mul-distributes-over-mult-add"
    ((a (gen-member '(:zero :one :omega)))
     (b (gen-member '(:zero :one :omega)))
     (c (gen-member '(:zero :one :omega))))
  (expect (mult-mul a (mult-add b c))
          :to-be (mult-add (mult-mul a b) (mult-mul a c))))

(it-property "mult-leq-reflexive"
    ((a (gen-member '(:zero :one :omega))))
  (expect (mult-leq a a) :to-be-truthy))
