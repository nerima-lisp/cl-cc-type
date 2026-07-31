;;;; t/actors-test.lisp — Typed Actors Tests
;;;;
;;;; Tests for src/actors.lisp (FR-2203):
;;;; typed actor message acceptance and stop semantics.

(in-package :cl-cc-type/test)

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

(it-sequential "tagged-pattern-rejects-length-mismatch-and-non-list-messages"
  (let ((actor (cl-cc/type:make-actor-ref '(:ping integer integer))))
    ;; Same leading keyword, but the message is shorter than the pattern:
    ;; (= (length pattern) (length message)) fails.
    (expect (cl-cc/type:actor-message-accepted-p actor '(:ping 5)) :to-be-falsy)
    ;; A bare non-cons message can never satisfy (consp message).
    (expect (cl-cc/type:actor-message-accepted-p actor 5) :to-be-falsy)
    ;; Same length and leading keyword, but a later slot fails its type check,
    ;; so the (loop ... always ...) walk must fail partway through.
    (expect (cl-cc/type:actor-message-accepted-p actor '(:ping 5 "not-an-integer")) :to-be-falsy)
    ;; All slots satisfy their element types: the loop succeeds to completion.
    (expect (cl-cc/type:actor-message-accepted-p actor '(:ping 5 6)) :to-be-truthy)))

(it-sequential "bare-keyword-pattern-matches-atom-or-tagged-list-messages"
  (let ((actor (cl-cc/type:make-actor-ref :ping)))
    ;; (keywordp pattern) branch, first disjunct: message eq pattern directly.
    (expect (cl-cc/type:actor-message-accepted-p actor :ping) :to-be-truthy)
    ;; (keywordp pattern) branch, second disjunct: message is a tagged list.
    (expect (cl-cc/type:actor-message-accepted-p actor '(:ping 5)) :to-be-truthy)
    ;; Neither disjunct holds for an unrelated keyword or tag.
    (expect (cl-cc/type:actor-message-accepted-p actor :pong) :to-be-falsy)
    (expect (cl-cc/type:actor-message-accepted-p actor '(:pong 5)) :to-be-falsy)))

(it-sequential "actor-ref-typed-pattern-accepts-any-message"
  ;; When the actor's message-type is itself an FR-2203 actor-ref type,
  ;; %message-pattern-matches-p short-circuits on (type-advanced-p pattern)
  ;; and accepts unconditionally, regardless of the message shape.
  (let ((actor (cl-cc/type:make-actor-ref (cl-cc/type:actor-ref-type 'integer))))
    (expect (cl-cc/type:actor-message-accepted-p actor 42) :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor "anything") :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor '(:whatever)) :to-be-truthy)))

(it-sequential "union-typed-pattern-matches-any-member-alternative"
  (let ((actor (cl-cc/type:make-actor-ref
                (cl-cc/type:make-type-union (list :ping :pong)))))
    (expect (cl-cc/type:actor-message-accepted-p actor :ping) :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor :pong) :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor :other) :to-be-falsy)))

(it-sequential "plain-list-pattern-matches-via-element-type-alternation"
  ;; A pattern that is a cons whose CAR is not a keyword falls through the
  ;; tagged-list clause to the generic (listp pattern) clause, which tries
  ;; each member as its own sub-pattern -- here plain type-name symbols that
  ;; land in the final %typed-channel-value-matches-p fallback clause.
  (let ((actor (cl-cc/type:make-actor-ref (list 'integer 'string))))
    (expect (cl-cc/type:actor-message-accepted-p actor 5) :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor "hi") :to-be-truthy)
    (expect (cl-cc/type:actor-message-accepted-p actor 'unrelated-symbol) :to-be-falsy)))

(it-sequential "actor-message-accepted-p-rejects-non-actor-values"
  (expect (cl-cc/type:actor-message-accepted-p "not-an-actor" :ping) :to-be-falsy))

(it-sequential "actor-send-errors-on-non-actor-values"
  (signals error
      (cl-cc/type:actor-send "not-an-actor" :ping)))

(it-sequential "actor-send-without-handler-still-enqueues-mailbox"
  (let ((actor (cl-cc/type:make-actor-ref :ping)))
    (expect (cl-cc/type:typed-actor-ref-mailbox actor) :to-equal nil)
    (expect (cl-cc/type:actor-send actor :ping) :to-be-truthy)
    (expect (cl-cc/type:typed-actor-ref-mailbox actor) :to-equal '(:ping))))

(it-sequential "make-actor-ref-remote-p-coerces-to-boolean"
  (let ((remote-actor (cl-cc/type:make-actor-ref :ping :remote-p t))
        (local-actor (cl-cc/type:make-actor-ref :ping)))
    (expect (cl-cc/type:typed-actor-ref-remote-p remote-actor) :to-be-truthy)
    (expect (cl-cc/type:typed-actor-ref-remote-p local-actor) :to-be-falsy)))

(it-sequential "actor-ref-type-builds-fr-2203-advanced-type-node"
  (let ((ty (cl-cc/type:actor-ref-type 'integer)))
    (expect (cl-cc/type:type-advanced-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-name ty) :to-be 'cl-cc/type::actor-ref)))

