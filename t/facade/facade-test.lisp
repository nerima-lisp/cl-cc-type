(in-package #:cl-cc/type/facade/test)

(defun %read-export-surface ()
  (let ((*read-eval* nil))
    (with-open-file
        (stream
         (asdf:system-relative-pathname "cl-cc-type/test" "t/export-surface.txt"))
      (read stream nil nil))))

(defun %check-export-snapshot-entry (row)
  (unless
      (and (= (length row) 6)
           (eq (first row) :symbol)
           (member (second row) '(:keep :add) :test #'eq))
    (error "Invalid facade export snapshot row: ~S" row))
  (destructuring-bind (kind change
                            facade-name
                            feature-name
                            home-name
                            symbol-name) row
    (declare (ignore kind change))
    (let ((facade (find-package (string-upcase facade-name)))
          (feature (find-package (string-upcase feature-name)))
          (home (find-package (string-upcase home-name))))
      (unless (and facade feature home)
        (error "Snapshot row names an unknown package: ~S" row))
      (multiple-value-bind (facade-symbol facade-status)
          (find-symbol symbol-name facade)
        (multiple-value-bind (feature-symbol feature-status)
            (find-symbol symbol-name feature)
          (expect facade-status :to-equal :external)
          (expect feature-status :to-equal :external)
          (expect (eq facade-symbol feature-symbol) :to-be-truthy)
          (expect (eq (symbol-package facade-symbol) home) :to-be-truthy))))))

(describe-concurrent "cl-cc/type private aliases"
                     (it-sequential "keeps the legacy ANY symbol internal"
                                    (let ((facade (find-package "CL-CC/TYPE"))
                                          (model
                                           (find-package
                                            "CL-CC/TYPE/TYPE-MODEL")))
                                      (multiple-value-bind (facade-any
                                                            facade-status)
                                          (find-symbol "ANY" facade)
                                        (multiple-value-bind (model-any
                                                              model-status)
                                            (find-symbol "ANY" model)
                                          (expect facade-status
                                                  :to-equal
                                                  :internal)
                                          (expect model-status
                                                  :to-equal
                                                  :internal)
                                          (expect (eq facade-any model-any)
                                                  :to-be-truthy)
                                          (expect
                                           (eq (symbol-package facade-any)
                                               model)
                                           :to-be-truthy))))))

(describe-concurrent "cl-cc/type facade export contract"
                     (it-sequential
                      "preserves the approved export surface and symbol homes"
                      (let* ((rows (%read-export-surface))
                             (expected (sort (mapcar #'sixth rows) #'string<))
                             (facade (find-package "CL-CC/TYPE"))
                             (actual nil))
                        (unless facade
                          (error "The cl-cc/type facade package is not defined"))
                        (do-external-symbols (symbol facade)
                                             (push (symbol-name symbol) actual))
                        (expect (sort actual #'string<) :to-equal expected)
                        (dolist (row rows)
                          (%check-export-snapshot-entry row)))))

(in-package #:cl-cc/type/facade/test)

(it-sequential "utility-types-compose-with-field-requirements-and-freeze"
  (let* ((record (make-type-record
                  :fields (list (cons 'name type-string)
                                (cons 'age type-int))
                  :row-var nil))
         (partial (partial-type record))
         (required (required-type partial))
         (frozen (freeze "value" type-string)))
    (expect (type-advanced-p (has-field-type 'name type-string))
            :to-be-truthy)
    (expect (type-union-p (get-field-type 'name partial)) :to-be-truthy)
    (expect type-string :to-be-type-equal-to (get-field-type 'name required))
    (expect (frozen-value-p frozen) :to-be-truthy)))
