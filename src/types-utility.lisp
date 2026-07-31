;;;; types-utility.lisp
;;;; FR-3303/3304 TS-style utility types (Readonly, Partial, Pick, Omit,
;;;; Exclude, Extract)

(in-package :cl-cc/type)

(defstruct frozen-value
  "Runtime wrapper produced by FR-3303 freeze."
  value
  type)

(defun readonly-type (type)
  "Construct a shallow FR-3303 readonly type."
  (make-type-capability :base type :cap 'readonly))

(defun writable-type (type)
  "Construct a writable marker used by readonly subtyping tests."
  (make-type-capability :base type :cap 'writable))

(defun deep-readonly-type (type)
  "Recursively mark TYPE as readonly."
  (cond
    ((type-record-p type)
     (readonly-type
      (make-type-record :fields (mapcar (lambda (field)
                                          (cons (car field) (deep-readonly-type (cdr field))))
                                        (type-record-fields type))
                        :row-var (type-record-row-var type))))
    ((type-union-p type)
     (readonly-type (make-type-union (mapcar #'deep-readonly-type (type-union-types type))
                                     :constructor-name (type-union-constructor-name type))))
    (t (readonly-type type))))

(defun freeze (value type)
  "Return VALUE wrapped with its FR-3303 readonly type."
  (make-frozen-value :value value :type (readonly-type type)))

(defun partial-type (type)
  "Make every record field optional (FR-3304 Partial<T>)."
  (if (type-record-p type)
      (make-type-record :fields (mapcar (lambda (field)
                                          (cons (car field)
                                                (make-type-union (list type-null (cdr field))
                                                                 :constructor-name 'option)))
                                        (type-record-fields type))
                        :row-var (type-record-row-var type))
      (make-type-union (list type-null type) :constructor-name 'option)))

(defun required-type (type)
  "Remove NULL from optional fields (FR-3304 Required<T>)."
  (if (type-record-p type)
      (make-type-record :fields (mapcar (lambda (field)
                                          (cons (car field) (non-nullable-type (cdr field))))
                                        (type-record-fields type))
                        :row-var (type-record-row-var type))
      (non-nullable-type type)))

(defun pick-type (type keys)
  "Select KEYS from a record type (FR-3304 Pick<T,K>)."
  (unless (type-record-p type)
    (error "pick-type expects a record type"))
  (make-type-record :fields (remove-if-not (lambda (field)
                                             (member (car field) keys :test #'%field-name=))
                                           (type-record-fields type))
                    :row-var nil))

(defun omit-type (type keys)
  "Omit KEYS from a record type (FR-3304 Omit<T,K>)."
  (unless (type-record-p type)
    (error "omit-type expects a record type"))
  (make-type-record :fields (remove-if (lambda (field)
                                         (member (car field) keys :test #'%field-name=))
                                       (type-record-fields type))
                    :row-var nil))

(defun %collapse-union-members (members constructor-name)
  "Collapse a filtered MEMBERS list back into a single type: no survivors
becomes TYPE-NULL, one survivor is unwrapped, and several are rewrapped as
a union tagged CONSTRUCTOR-NAME. Shared tail of EXCLUDE-TYPE, EXTRACT-TYPE,
and NON-NULLABLE-TYPE, which differ only in how they filter the members."
  (cond ((null members) type-null)
        ((null (rest members)) (first members))
        (t (make-type-union members :constructor-name constructor-name))))

(defun exclude-type (union excluded)
  "Remove EXCLUDED from UNION (FR-3304 Exclude<T,U>)."
  (if (type-union-p union)
      (%collapse-union-members
       (remove-if (lambda (member)
                    (or (type-equal-p member excluded)
                        (is-subtype-p member excluded)))
                  (type-union-types union))
       (type-union-constructor-name union))
      (if (is-subtype-p union excluded) type-null union)))

(defun extract-type (union target)
  "Keep members of UNION assignable to TARGET (FR-3304 Extract<T,U>)."
  (if (type-union-p union)
      (%collapse-union-members
       (remove-if-not (lambda (member) (is-subtype-p member target))
                       (type-union-types union))
       (type-union-constructor-name union))
      (if (is-subtype-p union target) union type-null)))

(defun non-nullable-type (type)
  "Remove NULL from TYPE (FR-3304 NonNullable<T>)."
  (if (type-union-p type)
      (%collapse-union-members
       (remove-if (lambda (member) (type-equal-p member type-null))
                  (type-union-types type))
       (type-union-constructor-name type))
      type))

(defun return-type-of (function-type)
  "Extract a function return type (FR-3304 ReturnType<T>)."
  (unless (type-arrow-p function-type)
    (error "return-type-of expects an arrow type"))
  (type-arrow-return function-type))
