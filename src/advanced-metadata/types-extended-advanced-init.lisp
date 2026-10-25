;;;; types-extended-advanced-init.lisp — make-type-advanced, %initialize-* functions, top-level call
(in-package :cl-cc/type/advanced-metadata)

(defun make-type-advanced (&key feature-id (name 'advanced) args properties evidence)
  "Construct a type-advanced node for FEATURE-ID."
  (let ((feature (or (lookup-type-advanced-feature feature-id)
                     (error "Unknown advanced feature id: ~S" feature-id))))
    (multiple-value-bind (normalized-args normalized-properties)
        (%type-advanced-normalize-payload
         (type-advanced-feature-fr-id feature)
         args
         (%type-advanced-normalize-properties properties))
      (validate-type-advanced
       (%make-type-advanced :feature-id (type-advanced-feature-fr-id feature)
                            :name name
                            :args (copy-list normalized-args)
                            :properties normalized-properties
                            :evidence evidence)))))

(defun make-type-dynamic (value-type &key properties evidence)
  "Construct a Dynamic feature node (FR-2501) around VALUE-TYPE."
  (make-type-advanced :feature-id "FR-2501"
                      :name 'dynamic
                      :args (list value-type)
                      :properties properties
                      :evidence evidence))

(defun make-type-type-rep (represented-type &key properties evidence)
  "Construct a TypeRep feature node (FR-2502) around REPRESENTED-TYPE."
  (make-type-advanced :feature-id "FR-2502"
                      :name 'typerep
                      :args (list represented-type)
                      :properties properties
                      :evidence evidence))

(defun %initialize-type-advanced-contract-registry ()
  "Populate the explicit advanced semantic contract registry."
  (clrhash *type-advanced-contract-registry*)
  (dolist (spec +type-advanced-contract-specs+)
    (register-type-advanced-contract
     (%make-type-advanced-contract-from-spec spec)))
  t)

(defun %initialize-type-advanced-implementation-evidence-registry ()
  "Populate the advanced implementation evidence registry."
  (clrhash *type-advanced-implementation-evidence-registry*)
  (dolist (spec +type-advanced-implementation-evidence-specs+)
    (register-type-advanced-implementation-evidence
     (%make-type-advanced-implementation-evidence-from-spec spec)))
  t)

(defun %ensure-type-advanced-contract-coverage ()
  "Ensure every tracked advanced feature id has exactly one explicit contract."
  (let* ((feature-ids (mapcar #'first +type-advanced-feature-specs+))
         (missing (remove-if #'lookup-type-advanced-contract feature-ids))
         (orphan nil))
    (maphash (lambda (feature-id _contract)
               (declare (ignore _contract))
               (unless (member feature-id feature-ids :test #'string=)
                 (push feature-id orphan)))
             *type-advanced-contract-registry*)
    (when missing
      (error "Missing advanced semantic contract(s) for ~{~A~^, ~}" missing))
    (when orphan
      (error "Orphan advanced semantic contract(s): ~{~A~^, ~}" (sort orphan #'string<)))
    (unless (= (hash-table-count *type-advanced-contract-registry*)
               (length feature-ids))
      (error "Advanced contract registry count (~D) does not match feature registry count (~D)"
             (hash-table-count *type-advanced-contract-registry*)
             (length feature-ids)))
    t))

(defun %ensure-type-advanced-implementation-evidence-coverage ()
  "Ensure every tracked advanced feature id has exactly one evidence record."
  (let* ((feature-ids (mapcar #'first +type-advanced-feature-specs+))
         (missing (remove-if #'lookup-type-advanced-implementation-evidence feature-ids))
         (orphan nil))
    (maphash (lambda (feature-id _evidence)
               (declare (ignore _evidence))
               (unless (member feature-id feature-ids :test #'string=)
                 (push feature-id orphan)))
             *type-advanced-implementation-evidence-registry*)
    (when missing
      (error "Missing advanced implementation evidence for ~{~A~^, ~}" missing))
    (when orphan
      (error "Orphan advanced implementation evidence: ~{~A~^, ~}" (sort orphan #'string<)))
    (unless (= (hash-table-count *type-advanced-implementation-evidence-registry*)
               (length feature-ids))
      (error (concatenate 'string
                          "Advanced implementation evidence count (~D) does not "
                          "match feature registry count (~D)")
             (hash-table-count *type-advanced-implementation-evidence-registry*)
             (length feature-ids)))
    t))

(defun %initialize-type-advanced-feature-registry ()
  "Populate the advanced feature and surface-head registries."
  (clrhash *type-advanced-feature-registry*)
  (clrhash *type-advanced-head-registry*)
  (dolist (spec +type-advanced-feature-specs+)
    (register-type-advanced-feature
     (make-type-advanced-feature :id (first spec) :title (second spec))))
  (dolist (spec +type-advanced-head-specs+)
    (register-type-advanced-head (car spec) (cdr spec)))
  (%initialize-type-advanced-contract-registry)
  (%initialize-type-advanced-implementation-evidence-registry)
  (%ensure-type-advanced-contract-coverage)
  (%ensure-type-advanced-implementation-evidence-coverage)
  t)

(%initialize-type-advanced-feature-registry)

(in-package :cl-cc/type/advanced-metadata)

(defmethod type-to-string ((ty type-advanced))
  (let* ((surface-head (type-advanced-name ty))
         (head (if (and (symbolp surface-head)
                        (not (string= (symbol-name surface-head) "ADVANCED")))
                   surface-head
                    'advanced))
         (feature-id (type-advanced-feature-id ty)))
    (with-output-to-string (out)
      (format out "(~A" (symbol-name head))
      (when (eq head 'advanced)
        (format out " ~A" feature-id))
      (dolist (arg (type-advanced-args ty))
        (format out " ~A" (%advanced-display-value arg)))
      (dolist (entry (type-advanced-properties ty))
        (format out " ~A ~A"
                (symbol-name (car entry))
                (%advanced-display-value (cdr entry))))
      (when (type-advanced-evidence ty)
        (format out " :EVIDENCE ~A"
                (%advanced-display-value (type-advanced-evidence ty))))
      (write-char #\) out))))

(defun %advanced-display-value (value)
  "Render nested advanced payload values using type printers where applicable."
  (cond
    ((typep value 'type-node) (type-to-string value))
    ((consp value)
     (format nil "(~{~A~^ ~})" (mapcar #'%advanced-display-value value)))
    (t (prin1-to-string value))))
