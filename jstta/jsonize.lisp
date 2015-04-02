; (load "jsonize.lisp")

(defun string-split (string &key (delimiter #\tab) (copy t) num-values)
  (let ((substrings '())
        (length (length string))
        (last 0))
    (flet ((add-substring (i)
             (push (if copy
                       (subseq string last i)
                     (make-array (- i last)
                                 :element-type 'character
                                 :displaced-to string
                                 :displaced-index-offset last))
              substrings)))
      (dotimes (i length)
        (when (eq (char string i) delimiter)
          (add-substring i)
          (setq last (1+ i))))
      (add-substring length)
      (nreverse substrings)
      )))

(with-open-file 
 (i "TargetedTherapyDatabase_TTD.txt")
 (with-open-file 
  (o "TargetedTherapyDatabase_TTD.json"
     :direction :output :if-exists :supersede)
  (format o "[~%")
  (read-line i nil nil) ;; Dump header
  (loop as line = (read-line i nil nil)
	as k from 1 by 1
	with comma-flag = nil ;; Adds commas after each except the first time.
	until (null line)
	do 
	(when (zerop (mod k 100)) (print k))
	(if (null comma-flag)
	    (setq comma-flag t)
	  (format o ",~%"))
	(format o "{")
	(loop for key in '("ID" "Source" "Molecule" "AliasMol" "DNAmRNAProtein" "StateMol" "Modifier" "AliasModifier" "Relationship" "DrugTherapy" "AliasDrug" "Model" "H" "Cases" "Reference" "Notes")
	      as value in (string-split line)
	      do
	      (format o "~s:~s" key (substitute #\- #\" value))
	      (unless (string-equal key "Notes") (format o ","))
	      )
	(format o "}")
	)
  (format o "~%]~%")
  ))

