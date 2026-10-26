(in-package :cl-cc/type/type-model)

(defmacro require-with-detail (predicate condition-type format-control &rest format-args)
  "Signal CONDITION-TYPE via ERROR-WITH-DETAIL unless PREDICATE holds."
  `(unless ,predicate
     (error-with-detail ,condition-type ,format-control ,@format-args)))

;;; ─── :detail-condition signaling macros ────────────────────────────────────
;;; types-extended-ffi.lisp and types-extended-routing-types.lisp both define
;;; their validation condition (FFI-VALIDATION-ERROR, ROUTE-VALIDATION-ERROR)
;;; with DEFINE-SIMPLE-CONDITION's :DETAIL slot convention, then repeatedly
;;; hand-write `(error 'CONDITION :detail (format nil "..." args))` — as a
;;; COND fallback clause in some places, guarded by an UNLESS in others.
;;; ERROR-WITH-DETAIL covers the shape itself; REQUIRE-WITH-DETAIL adds the
;;; UNLESS guard for call sites that need one.

(defmacro error-with-detail (condition-type format-control &rest format-args)
  "Signal CONDITION-TYPE with a :DETAIL initarg built from
(format nil FORMAT-CONTROL . FORMAT-ARGS)."
  `(error ',condition-type :detail (format nil ,format-control ,@format-args)))

;;; ─── Keyword-normalizing function macro ───────────────────────────────────
;;; Several files define a function that normalizes a symbol/string/keyword
;;; designator into a keyword using the exact same four-branch COND.
;;; DEFINE-KEYWORD-NORMALIZER generates that function so call sites do not
;;; hand-write the COND. Normalizers with different fallback semantics (for
;;; example, signaling an error instead of returning the value unchanged, or
;;; upcasing a symbol's name before interning) are genuinely different and
;;; are left hand-written at their call sites.

(defmacro define-keyword-normalizer (name (param) documentation)
  "Define NAME (PARAM), a function that normalizes PARAM into a keyword:
keywords pass through unchanged, symbols intern by name, strings intern
upcased, and anything else is returned as-is."
  `(defun ,name (,param)
     ,documentation
     (cond
       ((keywordp ,param) ,param)
       ((symbolp ,param) (intern (symbol-name ,param) :keyword))
       ((stringp ,param) (intern (string-upcase ,param) :keyword))
       (t ,param))))

;;; ─── Simple-condition-defining macro ──────────────────────────────────────
;;; Several files in this system define a condition with the shape "one
;;; error class, N :initarg/:reader slots that follow the NAME-SLOT naming
;;; convention, and a single-clause :report that FORMATs a fixed template
;;; against the condition's own readers". DEFINE-SIMPLE-CONDITION generates
;;; that shape so call sites do not hand-write the :initarg/:reader/:report
;;; boilerplate. Conditions whose :report needs more than a straight FORMAT
;;; call against CONDITION, or whose slots do not follow the NAME-SLOT
;;; convention, are left hand-written at their call sites.

(defmacro define-simple-condition (name parent slots &optional report-control &rest report-args)
  "Define condition NAME inheriting from PARENT with SLOTS.

Each element of SLOTS is either a slot name or (SLOT-NAME INITFORM); every
slot gets an :initarg matching its keywordized name and a NAME-SLOT-NAME
reader.

When REPORT-CONTROL is non-nil, also attach a (:report ...) clause whose
body is (format stream REPORT-CONTROL ,@REPORT-ARGS), with CONDITION bound
to the signaled condition instance."
  `(define-condition ,name (,parent)
     ,(mapcar (lambda (slot)
                (let ((slot-name (if (consp slot) (first slot) slot)))
                  `(,slot-name
                    :initarg ,(intern (symbol-name slot-name) :keyword)
                    ,@(when (consp slot) `(:initform ,(second slot)))
                    :reader ,(intern (format nil "~A-~A" name slot-name)))))
              slots)
     ,@(when report-control
         `((:report (lambda (condition stream)
                      (declare (ignorable condition))
                      (format stream ,report-control ,@report-args)))))))
