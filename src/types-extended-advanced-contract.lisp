;;;; types-extended-advanced-contract.lisp — type-advanced-contract struct and its registry
(in-package :cl-cc/type)

(defstruct (type-advanced-contract (:constructor %make-type-advanced-contract))
  "Explicit per-FR semantic validation contract for an advanced feature."
  (feature-id "" :type string)
  (semantic-domain nil)
  (exact-args nil)
  (min-args nil)
  (required-properties nil :type list)
  (property-predicates nil :type list)
  (requires-evidence-p nil :type boolean)
  (evidence-predicate nil)
  (custom-validator nil)
  (summary "" :type string))

(defvar *type-advanced-contract-registry* (make-hash-table :test #'equal)
  "Maps canonical advanced FR ids to explicit semantic contracts.")

(defun make-type-advanced-contract (&key id semantic-domain exact-args min-args
                                      required-properties property-predicates
                                      requires-evidence-p evidence-predicate
                                      custom-validator summary)
  "Construct an explicit semantic contract for advanced FEATURE-ID."
  (let ((feature-id (canonicalize-type-advanced-feature-id id)))
    (unless semantic-domain
      (error "Advanced contract ~A requires a semantic domain" feature-id))
    (unless (or exact-args min-args required-properties property-predicates
                requires-evidence-p evidence-predicate custom-validator)
      (error "Advanced contract ~A must encode at least one validation rule" feature-id))
    (%make-type-advanced-contract :feature-id feature-id
                                  :semantic-domain semantic-domain
                                  :exact-args exact-args
                                  :min-args min-args
                                  :required-properties (copy-list required-properties)
                                  :property-predicates (copy-tree property-predicates)
                                  :requires-evidence-p requires-evidence-p
                                  :evidence-predicate evidence-predicate
                                  :custom-validator custom-validator
                                  :summary (or summary ""))))

(defun %type-advanced-contract-spec (id semantic-domain &rest options)
  "Build a plist specification for the contract covering FEATURE-ID."
  (list* :id id :semantic-domain semantic-domain options))

(defun %type-advanced-contract-specs (ids semantic-domain &rest options)
  "Build contract plist specs for each id in IDS."
  (mapcar (lambda (id)
            (apply #'%type-advanced-contract-spec id semantic-domain options))
          ids))

(defun register-type-advanced-contract (contract)
  "Register CONTRACT and return it."
  (let ((feature-id (type-advanced-contract-feature-id contract)))
    (unless (lookup-type-advanced-feature feature-id)
      (error "Cannot register a contract for unknown advanced feature id ~A" feature-id))
    (when (gethash feature-id *type-advanced-contract-registry*)
      (error "Duplicate advanced contract for ~A" feature-id))
    (setf (gethash feature-id *type-advanced-contract-registry*) contract)
    contract))

(defun lookup-type-advanced-contract (feature-id)
  "Return the explicit semantic contract registered for FEATURE-ID, or NIL."
  (gethash (canonicalize-type-advanced-feature-id feature-id)
           *type-advanced-contract-registry*))
