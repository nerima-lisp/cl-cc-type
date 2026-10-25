;;;; types-extended-advanced-validators.lisp — 22 %type-advanced-validate-* functions
(in-package :cl-cc/type)

;;; VALIDATE-ADVANCED covers the recurring shape "signal %TYPE-ADVANCED-INVALID
;;; unless a predicate holds" that appears throughout this file's per-feature
;;; validators. It is not a general (unless ...) replacement: only guards that
;;; report through %TYPE-ADVANCED-INVALID on ADVANCED fit it, and several
;;; validators below still hand-write an UNLESS/WHEN because their guard does
;;; something the macro does not cover (COND dispatch on more than one
;;; outcome, a WHEN whose condition is "invalid" rather than "valid", or two
;;; independent conditions reported with different messages inline) — those
;;; stay as they are, the same boundary REGISTRY.LISP's own macros draw.

(defmacro validate-advanced (advanced predicate &rest report-args)
  "Signal an invalid-advanced-type error via %TYPE-ADVANCED-INVALID — called
as (%TYPE-ADVANCED-INVALID ADVANCED . REPORT-ARGS), so REPORT-ARGS is a
format-control string followed by its format arguments — unless PREDICATE
is true."
  `(unless ,predicate
     (%type-advanced-invalid ,advanced ,@report-args)))

(defun %type-advanced-validate-information-flow (advanced)
  "Validate FR-1503 information-flow labels and declassification evidence."
  (%type-advanced-require-min-args advanced 1)
  (let* ((source (%type-advanced-payload-security-label (first (type-advanced-args advanced))))
         (target (type-advanced-property advanced :flow)))
    (when (and target (null (%type-advanced-label-rank target)))
      (%type-advanced-invalid advanced "unknown information-flow target label ~S" target))
    (when (and source target
               (not (type-advanced-security-label<= source target))
               (null (type-advanced-evidence advanced)))
      (%type-advanced-invalid advanced "flow from ~S to ~S requires declassification evidence"
                              source target))))

(defun %type-advanced-validate-type-safe-ffi (advanced)
  "Validate FR-2103 typed FFI descriptors at the boundary shape level."
  (%type-advanced-require-min-args advanced 1)
  (dolist (arg (type-advanced-args advanced))
    (validate-advanced advanced (ffi-descriptor-form-valid-p arg)
                        "malformed FFI descriptor ~S" arg)))

(defun %type-advanced-validate-route (advanced)
  "Validate FR-3305 API route payloads."
  (%type-advanced-require-min-args advanced 1)
  (dolist (route (type-advanced-args advanced))
    (validate-advanced advanced (type-advanced-route-p route)
                        "malformed route payload ~S" route)))

(defun %type-advanced-validate-proof-like (advanced)
  "Validate proof/totality features that require machine-checkable evidence.
Evidence presence itself is already enforced generically by
%TYPE-ADVANCED-VALIDATE-CONTRACT's :REQUIRES-EVIDENCE-P check, which every
FR dispatching here sets and which runs before this custom validator; only
the feature-id-specific evidence *shape* checks below belong here."
  (%type-advanced-require-min-args advanced 1)
  (let ((evidence (type-advanced-evidence advanced))
        (feature-id (type-advanced-feature-id advanced)))
    (when (member feature-id '("FR-1901" "FR-1902" "FR-1903" "FR-1904" "FR-1905" "FR-1906")
                  :test #'string=)
      (validate-advanced advanced
                          (or (termination-evidence-p evidence)
                              (termination-evidence-form-valid-p evidence)
                              (proof-evidence-form-valid-p evidence))
                          "malformed totality evidence ~S" evidence))
    (when (member feature-id '("FR-2001" "FR-2002" "FR-2003" "FR-2004" "FR-2005" "FR-3406")
                  :test #'string=)
      (validate-advanced advanced
                          (or (proof-evidence-form-valid-p evidence)
                              (cic-proof-valid-p evidence))
                          "malformed proof evidence ~S" evidence))))

(defun %type-advanced-validate-incremental-checking (advanced)
  "Validate FR-1606 incremental type-checking cache contracts."
  (let ((dependency-graph (type-advanced-property advanced :dependency-graph))
        (cache (type-advanced-property advanced :cache)))
    (when (equal dependency-graph cache)
      (%type-advanced-invalid advanced
                              "dependency graph and cache descriptors must be distinct, got ~S"
                              dependency-graph))))

(defun %type-advanced-validate-staging (advanced)
  "Validate FR-1703 staged payloads and stage transitions."
  (let* ((payload (first (type-advanced-args advanced)))
         (stage (type-advanced-property advanced :stage))
         (transition (%type-advanced-normalize-symbol-keyword
                      (type-advanced-property advanced :transition))))
    (validate-advanced advanced
                        (or (typep payload 'type-node)
                            (%type-advanced-staged-form-p payload))
                        "staging payload must be a code/run/splice form or type node, got ~S"
                        payload)
    (when (member transition '(:run :splice) :test #'eq)
      (validate-advanced advanced (type-advanced-evidence advanced)
                          "~S transition requires stage-safety evidence"
                          transition))
    (when (and (eq transition :run)
               (not (or (eql stage 1)
                        (eq (%type-advanced-normalize-symbol-keyword stage) :code))))
      (%type-advanced-invalid advanced
                              ":run transition requires stage 1 / :code input, got ~S"
                              stage))))

(defun %type-advanced-validate-optics (advanced)
  "Validate FR-1801 optic descriptors."
  (let ((payload (first (type-advanced-args advanced))))
    (validate-advanced advanced (%type-advanced-optic-form-p payload)
                        "optics payload must be a lens/prism/traversal descriptor, got ~S"
                        payload)))

(defun %type-advanced-validate-test-generation (advanced)
  "Validate FR-2101 type-directed generator configuration."
  (let ((coverage-target (type-advanced-property advanced :coverage-target))
        (samples (type-advanced-property advanced :samples)))
    (when (and samples (> samples coverage-target))
      (%type-advanced-invalid advanced
                              ":samples must not exceed :coverage-target (~S > ~S)"
                              samples
                              coverage-target))))

(defun %type-advanced-validate-smt-integration (advanced)
  "Validate FR-2406 SMT integration metadata."
  (validate-advanced advanced
                      (or (type-advanced-evidence advanced)
                          (type-advanced-property-present-p advanced :counterexample))
                      "SMT integration requires either proof evidence or a :counterexample ~
                       payload"))

(defun %type-advanced-validate-abstract-interpretation (advanced)
  "Validate FR-2804 abstract-interpretation descriptors."
  (let ((widening (type-advanced-property advanced :widening))
        (narrowing (type-advanced-property advanced :narrowing)))
    (when (and (type-advanced-property-present-p advanced :narrowing)
               (equal widening narrowing))
      (%type-advanced-invalid advanced
                              "widening and narrowing descriptors must differ, got ~S"
                              widening))))

(defun %type-advanced-validate-alias-analysis (advanced)
  "Validate FR-2902 alias-analysis descriptors."
  (let ((left (first (type-advanced-args advanced)))
        (right (second (type-advanced-args advanced)))
        (disjoint (type-advanced-property advanced :disjoint)))
    (validate-advanced advanced (%type-advanced-pointerish-form-p left)
                        "left alias operand must be pointer-like, got ~S" left)
    (validate-advanced advanced (%type-advanced-pointerish-form-p right)
                        "right alias operand must be pointer-like, got ~S" right)
    (when (and disjoint (equal left right))
      (%type-advanced-invalid advanced
                              "disjoint alias operands must not be structurally identical: ~S"
                              left))))

(defun %type-advanced-validate-plugins (advanced)
  "Validate FR-3002 plugin hook descriptors."
  (validate-advanced advanced
                      (%type-advanced-symbolic-designator-p (first (type-advanced-args advanced)))
                      "plugin descriptor must start with a symbolic plugin name"))

(defun %type-advanced-validate-synthesis (advanced)
  "Validate FR-3003 synthesis strategy descriptors."
  (let ((strategy (%type-advanced-normalize-symbol-keyword
                   (type-advanced-property advanced :search))))
    (when (and (eq strategy :proof-search)
               (null (type-advanced-evidence advanced)))
      (%type-advanced-invalid
       advanced
       "proof-search synthesis requires evidence describing the proof search goal"))))

(defun %type-advanced-validate-brand (advanced)
  "Validate FR-3205 branded-type payloads."
  (validate-advanced advanced
                      (or (symbolp (first (type-advanced-args advanced)))
                          (stringp (first (type-advanced-args advanced))))
                      "brand-type requires a symbolic brand name"))

(defun %type-advanced-validate-mapped-types (advanced)
  "Validate FR-3301 mapped-type transforms."
  (let ((base (first (type-advanced-args advanced)))
        (filter (type-advanced-property advanced :filter :absent)))
    (validate-advanced advanced
                        (or (typep base 'type-node)
                            (consp base)
                            (%type-advanced-symbolic-designator-p base))
                        "mapped-type base must be a type node or structured type form, got ~S"
                        base)
    (when (and (not (eq filter :absent))
               (not (or (%type-advanced-symbolic-designator-p filter)
                        (consp filter)
                        (typep filter 'type-node))))
      (%type-advanced-invalid advanced
                              ":filter must be a symbolic predicate or type form, got ~S"
                              filter))))

(defun %type-advanced-validate-conditional-types (advanced)
  "Validate FR-3302 conditional/infer-type descriptors.
:INFER's own shape is already checked by the contract's registered
:INFER property-predicate (%TYPE-ADVANCED-SYMBOLIC-DESIGNATOR-P) before
this custom validator ever runs; only the branch-distinctness rule below,
which no property-predicate could express, belongs here."
  (let ((then-branch (type-advanced-property advanced :then))
        (else-branch (type-advanced-property advanced :else)))
    (when (equal then-branch else-branch)
      (%type-advanced-invalid advanced
                              "conditional branches must differ to encode a real type split, got ~S"
                              then-branch))))

(defun %type-advanced-validate-encodings (advanced)
  "Validate FR-3403 functional data encoding descriptors."
  (let* ((encoding (%type-advanced-normalize-symbol-keyword
                    (type-advanced-property advanced :encoding)))
         (head-name (string-upcase (symbol-name (type-advanced-name advanced))))
         (expected (cond
                     ((string= head-name "CHURCH-ENCODING") :church)
                     ((string= head-name "SCOTT-ENCODING") :scott)
                     ((string= head-name "PARIGOT-ENCODING") :parigot)
                     (t nil))))
    (when (and expected (not (eq expected encoding)))
      (%type-advanced-invalid advanced
                              "encoding property ~S must agree with surface head ~S"
                              encoding
                              (type-advanced-name advanced)))))

(defun %type-advanced-validate-extensible-effects (advanced)
  "Validate FR-3404 extensible-effect descriptors."
  (let ((effects (first (type-advanced-args advanced))))
    (validate-advanced advanced (%type-advanced-effect-label-list-p effects)
                        "extensible effects require a non-empty list of unique effect ~
                         labels, got ~S"
                        effects)))

(defun %type-advanced-validate-type-theory-equality (advanced)
  "Validate FR-3405 equality-mode descriptors."
  (let* ((mode (%type-advanced-normalize-symbol-keyword
                (type-advanced-property advanced :mode)))
         (left (first (type-advanced-args advanced)))
         (right (second (type-advanced-args advanced))))
    (cond
      ((eq mode :intensional)
       (validate-advanced advanced (type-advanced-payload-equal-p left right)
                           "intensional equality requires computationally identical ~
                            payloads, got ~S and ~S"
                           left
                           right))
      ;; %TYPE-ADVANCED-EQUALITY-MODE-P's registered property-predicate
      ;; (types-extended-advanced-meta-validators.lisp) already restricts
      ;; :MODE to exactly "INTENSIONAL"/"EXTENSIONAL"/"OBSERVATIONAL" before
      ;; this custom validator ever runs; having ruled out :INTENSIONAL
      ;; above, MODE can only be :EXTENSIONAL or :OBSERVATIONAL here.
      (t
       (validate-advanced advanced (type-advanced-evidence advanced)
                           "~S equality requires supporting evidence"
                           mode)))))

(defun %type-advanced-validate-qtt (advanced)
  "Validate FR-3401 quantitative multiplicity payloads."
  (validate-advanced advanced (valid-multiplicity-p (first (type-advanced-args advanced)))
                      "unsupported QTT multiplicity ~S"
                      (first (type-advanced-args advanced))))

(defun %type-advanced-validate-graded (advanced)
  "Validate FR-3402 graded-type multiplicity payloads."
  (validate-advanced advanced (%type-advanced-multiplicity-p (first (type-advanced-args advanced)))
                      "unsupported multiplicity/grade ~S"
                      (first (type-advanced-args advanced))))
