(in-package :cl-cc/type/type-lowering)

;;; ─── Parser guard-and-report macro ─────────────────────────────────────────
;;; parser.lisp and parser-extended.lisp are full of "signal TYPE-PARSE-ERROR
;;; unless this shape-check holds" guards — over twenty of them, one per
;;; compound-type-syntax arity/shape rule. PARSER-REQUIRE generates that
;;; shape so call sites do not hand-write UNLESS + TYPE-PARSE-ERROR every
;;; time. Guards embedded in a COND clause (the clause condition already is
;;; the check) do not use it — there is no UNLESS to fold away there.

(defmacro parser-require (predicate format-control &rest format-args)
  "Signal TYPE-PARSE-ERROR via FORMAT-CONTROL/FORMAT-ARGS unless PREDICATE
holds."
  `(unless ,predicate
     (type-parse-error ,format-control ,@format-args)))
