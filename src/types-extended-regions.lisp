;;;; types-extended-regions.lisp — Region lifetime tokens, region-scoped references, with-region

(in-package :cl-cc/type)

(define-simple-condition region-lifetime-error error
  (reference)
  "Region reference ~S is no longer valid" (region-lifetime-error-reference condition))

(defvar *region-counter* 0
  "Monotone id source for region tokens.")

(defstruct (region-token (:constructor %make-region-token))
  "A concrete region lifetime token."
  (id 0 :type integer)
  (generation 0 :type integer)
  (active-p t :type boolean))

(defstruct region-ref
  "A value allocated inside a region."
  (token nil)
  (generation 0 :type integer)
  (value nil))

(defun make-region-token ()
  "Create a fresh active region token."
  (%make-region-token :id (incf *region-counter*)
                      :generation 0
                      :active-p t))

(defun close-region (region-token)
  "Invalidate REGION-TOKEN and bump its generation."
  (setf (region-token-active-p region-token) nil)
  (incf (region-token-generation region-token))
  region-token)

(defun region-active-p (region-token)
  "Return T when REGION-TOKEN is still active."
  (and (region-token-p region-token)
       (region-token-active-p region-token)))

(defun region-alloc (region-token value)
  "Allocate VALUE inside REGION-TOKEN."
  (unless (region-active-p region-token)
    (error "Cannot allocate in inactive region ~S" region-token))
  (make-region-ref :token region-token
                   :generation (region-token-generation region-token)
                   :value value))

(defun region-ref-valid-p (region-ref)
  "Return T when REGION-REF still points into a live region generation."
  (and (region-ref-p region-ref)
       (region-token-p (region-ref-token region-ref))
       (region-active-p (region-ref-token region-ref))
       (= (region-ref-generation region-ref)
          (region-token-generation (region-ref-token region-ref)))))

(defun region-deref (region-ref)
  "Read REGION-REF or signal REGION-LIFETIME-ERROR when dead."
  (unless (region-ref-valid-p region-ref)
    (error 'region-lifetime-error :reference region-ref))
  (region-ref-value region-ref))

(defmacro with-region ((name) &body body)
  "Evaluate BODY with NAME bound to a fresh region token."
  `(let ((,name (make-region-token)))
     (unwind-protect
          (progn ,@body)
       (close-region ,name))))
