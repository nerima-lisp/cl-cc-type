;;;; t/channels-test.lisp — Typed Channels Tests
;;;;
;;;; Tests for src/channels/channels.lisp (FR-2202):
;;;; buffered channel capacity, payload-type enforcement, and close semantics.

(in-package :cl-cc/type/channels/test)

(it-sequential "concrete-channels-enforce-capacity-type-and-close-semantics"
  (multiple-value-bind (sender receiver) (make-buffered-channel 'integer 1)
    (expect (channel-payload-type sender) :to-be 'integer)
    (expect (channel-send sender 7) :to-be-truthy)
    (signals error
        (channel-send sender 8))
    (expect (channel-recv receiver) :to-equal 7)
    (expect (channel-recv receiver) :to-be-null)
    (signals error
        (channel-send sender "wrong"))
    (close-typed-channel sender)
    (signals error
        (channel-send sender 9))))

(it-sequential "make-typed-channel-rejects-invalid-capacity"
  (signals error
      (make-typed-channel 'integer :capacity -1))
  (signals error
      (make-typed-channel 'integer :capacity "one")))

(it-sequential "channel-send-and-recv-reject-wrong-endpoint-kind"
  (multiple-value-bind (sender receiver) (make-typed-channel 'integer)
    (signals error
        (channel-send receiver 1))
    (signals error
        (channel-recv sender))))

(it-sequential "channel-payload-type-and-close-typed-channel-accept-any-endpoint-kind"
  ;; Both etypecase forms in src/channels/channels.lisp branch on send-channel,
  ;; recv-channel, or the raw typed-channel struct; the main test above only
  ;; ever exercises the send-channel arm, so drive the other two here.
  (multiple-value-bind (sender receiver) (make-typed-channel 'integer)
    (let ((channel (send-channel-channel sender)))
      (expect (channel-payload-type receiver) :to-be 'integer)
      (expect (channel-payload-type channel) :to-be 'integer)
      (close-typed-channel receiver)
      (expect (funcall (internal-function "cl-cc/type/channels" "TYPED-CHANNEL-CLOSED-P") channel) :to-be-truthy)))
  (multiple-value-bind (sender2 receiver2) (make-typed-channel 'integer)
    (declare (ignore sender2))
    (let ((channel2 (recv-channel-channel receiver2)))
      (close-typed-channel channel2)
      (expect (funcall (internal-function "cl-cc/type/channels" "TYPED-CHANNEL-CLOSED-P") channel2) :to-be-truthy))))

(it-sequential "channel-payload-type-and-close-typed-channel-reject-a-non-endpoint-value"
  ;; Both ETYPECASE forms' final (TYPED-CHANNEL ENDPOINT) clause test had
  ;; only ever been observed TRUE across every prior test (it's always
  ;; reached with a genuine SEND-CHANNEL, RECV-CHANNEL, or TYPED-CHANNEL
  ;; object); its own FALSE outcome -- and the implicit ETYPECASE error
  ;; that follows when no clause matches at all -- had never fired.
  (signals error (channel-payload-type "not-a-channel"))
  (signals error (close-typed-channel "not-a-channel")))

(it-sequential "channel-payload-type-designator-resolves-across-representations"
  ;; %runtime-type-designator/%typed-channel-value-matches-p branch on
  ;; whether the payload type is a type-primitive, a type-advanced node, a
  ;; type-constructor, a plain symbol, or none of those -- exercise each.
  (multiple-value-bind (any-sender any-receiver)
      (make-typed-channel type-any)
    (declare (ignore any-receiver))
    (expect (channel-send any-sender :anything) :to-be-truthy))
  (multiple-value-bind (any-symbol-sender any-symbol-receiver)
      ;; Must be type-model internal ANY specifically: %typed-channel-value-matches-p
      ;; does (eq designator 'any) against the symbol as read inside
      ;; src/channels/channels.lisp's (in-package :cl-cc/type), which is a different
      ;; symbol from a bare 'any read in this file's own package.
      (make-typed-channel (internal-symbol "cl-cc/type/type-model" "ANY"))
    (declare (ignore any-symbol-receiver))
    (expect (channel-send any-symbol-sender :anything) :to-be-truthy))
  (multiple-value-bind (ctor-sender ctor-receiver)
      ;; A non-empty args list is required: MAKE-TYPE-CONSTRUCTOR with NIL
      ;; args degenerates to a bare TYPE-PRIMITIVE (already covered above),
      ;; not a TYPE-APP, so TYPE-CONSTRUCTOR-P would never see it.
      (make-typed-channel
       (make-type-constructor 'vector (list 'integer)))
    (declare (ignore ctor-receiver))
    (expect (channel-send ctor-sender #(1 2 3)) :to-be-truthy))
  (multiple-value-bind (advanced-sender advanced-receiver)
      ;; MAKE-TYPE-ADVANCED validates FEATURE-ID/NAME/ARGS against the FR-2202
      ;; contract, so a hand-rolled advanced type is rejected before it ever
      ;; reaches %runtime-type-designator; MAKE-CHANNEL-TYPE already returns a
      ;; contract-valid type-advanced node whose NAME (CHANNEL) is not a real
      ;; CL type specifier, so TYPEP on it signals and the IGNORE-ERRORS in
      ;; %typed-channel-value-matches-p must swallow that.
      (make-typed-channel (make-channel-type 'integer))
    (declare (ignore advanced-receiver))
    (signals error
        (channel-send advanced-sender 5)))
  (multiple-value-bind (catchall-sender catchall-receiver)
      (make-typed-channel 42)
    (declare (ignore catchall-receiver))
    (expect (channel-send catchall-sender :anything) :to-be-truthy)))

(it-sequential "make-channel-type-builds-fr-2202-advanced-type-per-direction"
  (let ((bidi (make-channel-type 'integer)))
    (expect (type-advanced-p bidi) :to-be-truthy)
    (expect (type-advanced-name bidi) :to-be (quote channel))
    (expect (type-advanced-args bidi) :to-equal '(integer)))
  (let ((send-only (make-channel-type 'integer :direction :send)))
    (expect (type-advanced-name send-only) :to-be (quote send-channel)))
  (let ((recv-only (make-channel-type 'integer :direction :recv)))
    (expect (type-advanced-name recv-only) :to-be (quote recv-channel)))
  (let ((buffered (make-channel-type 'integer :capacity 4)))
    (expect (cdr (assoc :capacity (type-advanced-properties buffered)))
            :to-be 4)))

