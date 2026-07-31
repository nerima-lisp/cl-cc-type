;;;; t/kind-test.lisp — Kind System Tests
;;;;
;;;; Tests for src/kind.lisp:
;;;; kind structs, kind-fun, kind-equal-p, kind-to-string, kind variables.

(in-package :cl-cc-type/test)

;;; ─── kind struct predicates ──────────────────────────────────────────────────

(it-sequential "kind-singleton-predicates type"
  (expect (funcall #'kind-type-p +kind-type+) :to-be-truthy))

(it-sequential "kind-singleton-predicates effect"
  (expect (funcall #'kind-effect-p +kind-effect+) :to-be-truthy))

(it-sequential "kind-singleton-predicates constraint"
  (expect (funcall #'cl-cc/type:kind-constraint-p +kind-constraint+) :to-be-truthy))

(it-sequential "kind-singleton-predicates multiplicity"
  (expect (funcall #'cl-cc/type:kind-multiplicity-p +kind-multiplicity+) :to-be-truthy))

(it-sequential "kind-row-singletons row-type"
  (expect (kind-row-p +kind-row-type+) :to-be-truthy)
  (expect (funcall #'kind-type-p (kind-row-elem +kind-row-type+)) :to-be-truthy))

(it-sequential "kind-row-singletons row-effect"
  (expect (kind-row-p +kind-row-effect+) :to-be-truthy)
  (expect (funcall #'kind-effect-p (kind-row-elem +kind-row-effect+)) :to-be-truthy))

;;; ─── kind-fun (arrow construction) ──────────────────────────────────────────

(it-sequential "kind-fun-builds-arrow"
  (let ((k (kind-fun +kind-type+ +kind-type+)))
    (expect (kind-arrow-p k) :to-be-truthy)
    (expect (kind-type-p (kind-arrow-from k)) :to-be-truthy)
    (expect (kind-type-p (kind-arrow-to k)) :to-be-truthy)))

(it-sequential "kind-fun-nested"
  (let ((k (kind-fun +kind-type+ (kind-fun +kind-type+ +kind-type+))))
    (expect (kind-arrow-p k) :to-be-truthy)
    (expect (kind-type-p (kind-arrow-from k)) :to-be-truthy)
    (expect (kind-arrow-p (kind-arrow-to k)) :to-be-truthy)))

;;; ─── kind variables ─────────────────────────────────────────────────────────

(it-sequential "kind-var-properties"
  (let ((kv  (fresh-kind-var))
        (kv1 (fresh-kind-var))
        (kv2 (fresh-kind-var))
        (kvn (fresh-kind-var "test")))
    (expect (kind-var-p kv) :to-be-truthy)
    (expect (kind-var-equal-p kv1 kv2) :to-be-falsy)
    (expect (kind-var-equal-p kv kv) :to-be-truthy)
    (expect (kind-var-p kvn) :to-be-truthy)
    (expect (cl-cc/type:kind-var-name kvn) :to-equal "test")))

;;; ─── kind-equal-p ───────────────────────────────────────────────────────────

(it-sequential "kind-equal-same type-type"
  (expect (kind-equal-p +kind-type+ +kind-type+) :to-be-truthy))

(it-sequential "kind-equal-same effect-effect"
  (expect (kind-equal-p +kind-effect+ +kind-effect+) :to-be-truthy))

(it-sequential "kind-equal-same constraint"
  (expect (kind-equal-p +kind-constraint+ +kind-constraint+) :to-be-truthy))

(it-sequential "kind-equal-same multiplicity"
  (expect (kind-equal-p +kind-multiplicity+ +kind-multiplicity+) :to-be-truthy))

(it-sequential "kind-not-equal-different type-vs-effect"
  (expect (kind-equal-p +kind-type+ +kind-effect+) :to-be-falsy))

(it-sequential "kind-not-equal-different type-vs-row"
  (expect (kind-equal-p +kind-type+ +kind-row-type+) :to-be-falsy))

(it-sequential "kind-not-equal-different effect-vs-row"
  (expect (kind-equal-p +kind-effect+ +kind-row-effect+) :to-be-falsy))

(it-sequential "kind-equal-arrow-and-row"
  (expect (kind-equal-p (kind-fun +kind-type+ +kind-type+)
                         (kind-fun +kind-type+ +kind-type+)) :to-be-truthy)
  (expect (kind-equal-p (kind-fun +kind-type+ +kind-effect+)
                         (kind-fun +kind-type+ +kind-type+)) :to-be-falsy)
  (expect (kind-equal-p +kind-row-type+ +kind-row-type+) :to-be-truthy)
  (expect (kind-equal-p +kind-row-type+ +kind-row-effect+) :to-be-falsy))

(it-sequential "kind-equal-arrow-mismatched-from-short-circuits-before-checking-to"
  ;; kind-equal-p's arrow clause is (AND (kind-equal-p from1 from2)
  ;; (kind-equal-p to1 to2)); the pre-existing arrow tests only ever have
  ;; FROM agree (so the AND's first conjunct is always true, and only its
  ;; second conjunct's truth value varies). Mismatch FROM itself so the
  ;; first conjunct is false and the AND short-circuits.
  (expect (kind-equal-p (kind-fun +kind-effect+ +kind-type+)
                         (kind-fun +kind-type+ +kind-type+)) :to-be-falsy))

;;; ─── kind-to-string ─────────────────────────────────────────────────────────

(it-sequential "kind-to-string-values star"
  (expect (kind-to-string +kind-type+) :to-equal "*"))

(it-sequential "kind-to-string-values effect"
  (expect (kind-to-string +kind-effect+) :to-equal "Effect"))

(it-sequential "kind-to-string-values constraint"
  (expect (kind-to-string +kind-constraint+) :to-equal "Constraint"))

(it-sequential "kind-to-string-values multiplicity"
  (expect (kind-to-string +kind-multiplicity+) :to-equal "Multiplicity"))

(it-sequential "kind-to-string-values row-star"
  (expect (kind-to-string +kind-row-type+) :to-equal "Row *"))

(it-sequential "kind-to-string-values row-effect"
  (expect (kind-to-string +kind-row-effect+) :to-equal "Row Effect"))

(it-sequential "kind-to-string-computed-kinds"
  (expect (kind-to-string (kind-fun +kind-type+ +kind-type+)) :to-equal "* -> *")
  (let ((inner (kind-fun +kind-type+ +kind-type+)))
    (expect (kind-to-string (kind-fun inner +kind-type+)) :to-equal "(* -> *) -> *"))
  (let ((kv (fresh-kind-var "foo")))
    (expect (kind-to-string kv) :to-equal "kfoo")))

(it-sequential "kind-type-singleton"
  (expect (kind-type-p +kind-type+) :to-be-truthy)
  (expect (kind-node-p +kind-type+) :to-be-truthy)
  (expect (kind-equal-p +kind-type+ +kind-type+) :to-be-truthy)
  (expect (kind-equal-p (make-kind-type) (make-kind-type)) :to-be-truthy))

(it-sequential "kind-arrow-creation"
  (let ((list-kind (kind-fun +kind-type+ +kind-type+)))
    (expect (kind-arrow-p list-kind) :to-be-truthy)
    (expect (kind-equal-p (kind-arrow-from list-kind) +kind-type+) :to-be-truthy)
    (expect (kind-equal-p (kind-arrow-to list-kind)   +kind-type+) :to-be-truthy)
    (let ((fix-kind (kind-fun list-kind +kind-type+)))
      (expect (kind-arrow-p fix-kind) :to-be-truthy)
      (expect (kind-equal-p (kind-arrow-from fix-kind) list-kind) :to-be-truthy))))

(it-sequential "kind-effect-row-singletons"
  (expect (kind-effect-p +kind-effect+) :to-be-truthy)
  (expect (kind-row-p +kind-row-type+) :to-be-truthy)
  (expect (kind-row-p +kind-row-effect+) :to-be-truthy)
  (expect (kind-equal-p (kind-row-elem +kind-row-type+)   +kind-type+) :to-be-truthy)
  (expect (kind-equal-p (kind-row-elem +kind-row-effect+) +kind-effect+) :to-be-truthy))

(it-sequential "kind-equal-p-basic *=*"
  (expect (kind-equal-p +kind-type+ +kind-type+) :to-be-truthy))

(it-sequential "kind-equal-p-basic Eff=Eff"
  (expect (kind-equal-p +kind-effect+ +kind-effect+) :to-be-truthy))

(it-sequential "kind-equal-p-basic *≠Eff"
  (expect (kind-equal-p +kind-type+ +kind-effect+) :to-be-falsy))

(it-sequential "kind-var-fresh-and-equality"
  (let ((k1 (fresh-kind-var 'k))
        (k2 (fresh-kind-var 'k)))
    (expect (kind-var-p k1) :to-be-truthy)
    (expect (kind-var-p k2) :to-be-truthy)
    (expect (kind-var-equal-p k1 k2) :to-be-falsy)
    (expect (kind-var-equal-p k1 k1) :to-be-truthy))
  (expect (kind-equal-p (kind-fun +kind-type+ +kind-type+)
                         (kind-fun +kind-type+ +kind-type+)) :to-be-truthy)
  (expect (kind-equal-p (kind-fun +kind-type+ +kind-effect+)
                         (kind-fun +kind-type+ +kind-type+)) :to-be-falsy))

;;; ─── kind-var-equal-p non-kind-var arguments ────────────────────────────────
;;; kind-var-equal-p short-circuits via (and (kind-var-p kv1) (kind-var-p kv2)
;;; ...); exercise both the "first arg not a kind-var" short-circuit and the
;;; "first is a kind-var but second is not" branch, neither of which is hit
;;; by passing two fresh-kind-var results.

(it-sequential "kind-var-equal-p-rejects-non-kind-var first-arg"
  (expect (kind-var-equal-p +kind-type+ (fresh-kind-var)) :to-be-falsy))

(it-sequential "kind-var-equal-p-rejects-non-kind-var second-arg"
  (expect (kind-var-equal-p (fresh-kind-var) +kind-type+) :to-be-falsy))

(it-sequential "kind-var-equal-p-rejects-non-kind-var both-args"
  (expect (kind-var-equal-p +kind-type+ +kind-effect+) :to-be-falsy))

;;; ─── kind-equal-p var-var branch ─────────────────────────────────────────────
;;; The (and (kind-var-p k1) (kind-var-p k2) (kind-var-equal-p k1 k2)) branch
;;; of kind-equal-p is not exercised anywhere above — every prior kind-equal-p
;;; test compares non-var kinds.

(it-sequential "kind-equal-p-var-var same-var"
  (let ((kv (fresh-kind-var)))
    (expect (kind-equal-p kv kv) :to-be-truthy)))

(it-sequential "kind-equal-p-var-var different-vars"
  (let ((kv1 (fresh-kind-var))
        (kv2 (fresh-kind-var)))
    (expect (kind-equal-p kv1 kv2) :to-be-falsy)))

;;; ─── kind-to-string for unnamed kind-var ────────────────────────────────────
;;; kind-to-string's kind-var clause has two sub-branches: named (format
;;; "k~A" name) already covered above, and unnamed (format "k~D" id), which
;;; is not exercised anywhere else.

(it-sequential "kind-to-string-unnamed-var uses-id"
  (let ((kv (fresh-kind-var)))
    (expect (cl-cc/type:kind-var-name kv) :to-be-falsy)
    (expect (kind-to-string kv) :to-equal (format nil "k~D" (cl-cc/type:kind-var-id kv)))))

;;; ─── kind-to-string fallback ─────────────────────────────────────────────────
;;; Every constructed kind-node subtype matches one of the cond clauses above,
;;; so the trailing (t "?") fallback clause is only reachable via a bare
;;; kind-node instance that isn't any of the named subtypes.

(it-sequential "kind-to-string-fallback bare-kind-node"
  (let ((bare (cl-cc/type::make-kind-node)))
    (expect (kind-node-p bare) :to-be-truthy)
    (expect (kind-type-p bare) :to-be-falsy)
    (expect (kind-to-string bare) :to-equal "?")))
