;;;; types-extended-capabilities.lisp — Capability sets, permission implication, restriction

(in-package :cl-cc/type)

(defstruct (capability (:constructor %make-capability))
  "A concrete capability set."
  (permissions nil :type list))

(defun %normalize-permission (permission)
  "Normalize PERMISSION into a keyword."
  (cond
    ((keywordp permission) permission)
    ((symbolp permission) (intern (symbol-name permission) :keyword))
    ((stringp permission) (intern (string-upcase permission) :keyword))
    (t (error "Unsupported permission designator: ~S" permission))))

(defun %suffixp (suffix string)
  "Return T when STRING ends with SUFFIX."
  (let ((suffix-length (length suffix))
        (string-length (length string)))
    (and (<= suffix-length string-length)
         (string= suffix string :start1 0 :start2 (- string-length suffix-length)))))

(defun %permission-read-variant (permission)
  "Return the read-only variant of PERMISSION when one exists."
  (let* ((normalized (%normalize-permission permission))
         (name (symbol-name normalized)))
    (cond
      ((%suffixp "-WRITE" name)
       (intern (concatenate 'string
                            (subseq name 0 (- (length name) 6))
                            "-READ")
               :keyword))
      ((%suffixp "-READ" name) normalized)
      (t nil))))

(defun %permission-closure (permission)
  "Return PERMISSION plus its implied permissions."
  (let* ((normalized (%normalize-permission permission))
         (read-variant (%permission-read-variant normalized)))
    (remove-duplicates (cons normalized (when read-variant (list read-variant)))
                       :test #'eq)))

(defun make-capability (permissions)
  "Construct a normalized capability set from PERMISSIONS."
  (%make-capability
   :permissions
   (sort (remove-duplicates (mapcan #'%permission-closure permissions) :test #'eq)
         #'string<
         :key #'symbol-name)))

(defun capability-allows-p (capability permission)
  "Return T when CAPABILITY allows PERMISSION."
  (member (%normalize-permission permission)
          (capability-permissions capability)
          :test #'eq))

(defun capability-implies-p (left right)
  "Return T when LEFT subsumes RIGHT.
RIGHT may be another capability or a single permission."
  (cond
    ((capability-p right)
     (every (lambda (permission)
              (capability-allows-p left permission))
            (capability-permissions right)))
    (t
     (capability-allows-p left right))))

(defun restrict-capability (capability restriction)
  "Restrict CAPABILITY according to RESTRICTION.
When RESTRICTION is :READ-ONLY, write permissions are downgraded to read permissions."
  (cond
    ((eq restriction :read-only)
     (make-capability
      (remove nil
              (mapcar #'%permission-read-variant
                      (capability-permissions capability)))))
    ((capability-p restriction)
     (make-capability
      (remove-if-not (lambda (permission)
                       (capability-allows-p restriction permission))
                     (capability-permissions capability))))
    ((listp restriction)
     (let ((allowed (make-capability restriction)))
       (restrict-capability capability allowed)))
    (t
     (error "Unsupported capability restriction: ~S" restriction))))

(defun capability-effects (capability)
  "Return effect keywords implied by CAPABILITY."
  (sort (remove-duplicates
         (mapcar (lambda (permission)
                   (let* ((name (symbol-name permission))
                          (split (position #\- name :from-end t)))
                     (if split
                         (intern (concatenate 'string
                                              (subseq name (1+ split))
                                              "-"
                                              (subseq name 0 split))
                                 :keyword)
                         permission)))
                 (capability-permissions capability))
         :test #'eq)
        #'string<
        :key #'symbol-name))
