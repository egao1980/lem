(in-package :lem)

(export '(*case-fold-search*
          search-forward
          search-backward
          search-forward-regexp
          search-backward-regexp
          search-forward-symbol
          search-backward-symbol
          looking-at-line))

(defvar *case-fold-search* nil)

(defun search-step (first-search search step goto-matched-pos endp)
  (let ((point (current-point))
        (result
         (let ((res (funcall first-search)))
           (cond (res
                  (funcall goto-matched-pos res)
                  (not (funcall endp)))
                 (t
                  (do () ((funcall endp))
                    (unless (funcall step)
                      (return nil))
                    (let ((res (funcall search)))
                      (when res
                        (funcall goto-matched-pos res)
                        (return t)))))))))
    (unless result
      (point-set point))
    result))

(defun search-forward-endp-function (limit)
  (if limit
      #'(lambda ()
          (or (point<= limit (current-point))
              (eobp)))
      #'eobp))

(defun search-forward (str &optional limit)
  (unless *case-fold-search*
    (setq str (string-downcase str)))
  (let ((length (1+ (count #\newline str))))
    (flet ((take-string ()
                        (let ((string
                               (join (string #\newline)
                                     (buffer-take-lines (current-buffer)
                                                        (current-linum)
                                                        length))))
                          (unless *case-fold-search*
                            (setq string (string-downcase string)))
                          string)))
      (search-step #'(lambda ()
                       (search str (take-string)
                               :start2 (current-charpos)))
                   #'(lambda ()
                       (search str (take-string)))
                   #'forward-line
                   #'(lambda (result)
                       (beginning-of-line)
                       (shift-position (+ result (length str))))
                   (search-forward-endp-function limit)))))

(defun search-backward-endp-function (limit)
  (if limit
      #'(lambda ()
          (point< (current-point) limit))
      #'bobp))

(defun search-backward (str &optional limit)
  (unless *case-fold-search*
    (setq str (string-downcase str)))
  (let ((length (1+ (count #\newline str))))
    (flet ((%search (&optional end)
                    (let ((linum (- (current-linum) (1- length))))
                      (when (< 0 linum)
                        (let* ((lines
                                (buffer-take-lines (current-buffer)
                                                   linum
                                                   length))
                               (string
                                (join (string #\newline)
                                      (if (and (< 1 linum) end)
                                          (append (butlast lines)
                                                  (list
                                                   (subseq (car (last lines))
                                                           0 end)))
                                          lines))))
                          (search str
                                  (if *case-fold-search*
                                      string
                                      (string-downcase string))
                                  :from-end t))))))
      (search-step #'(lambda ()
                       (%search (current-charpos)))
                   #'%search
                   #'(lambda () (forward-line -1))
                   #'(lambda (i)
                       (and (if (< 1 length)
                                (forward-line (- (1- length)))
                                t)
                            (beginning-of-line)
                            (shift-position i)))
                   (search-backward-endp-function limit)))))

(defun search-forward-regexp (regex &optional limit)
  (let (scanner)
    (handler-case (setq scanner (ppcre:create-scanner regex))
      (error () (return-from search-forward-regexp nil)))
    (search-step
     #'(lambda ()
         (let ((str (current-line-string)))
           (multiple-value-bind (start end)
               (ppcre:scan scanner
                           str
                           :start (current-charpos))
             (when (and start
                        (if (= start end)
                            (< (current-charpos) start)
                            (<= (current-charpos) start)))
               (if (= start end)
                   (1+ end)
                   end)))))
     #'(lambda ()
         (multiple-value-bind (start end)
             (ppcre:scan scanner
                         (current-line-string))
           (when start end)))
     #'forward-line
     #'set-charpos
     (search-forward-endp-function limit))))

(defun search-backward-regexp (regex &optional limit)
  (let (scanner)
    (handler-case (setq scanner (ppcre:create-scanner regex))
      (error () (return-from search-backward-regexp nil)))
    (search-step
     #'(lambda ()
         (let (pos)
           (ppcre:do-scans (start
                            end
                            reg-starts
                            reg-ends
                            scanner
                            (current-line-string)
                            nil
                            :end (current-charpos))
             (setq pos start))
           pos))
     #'(lambda ()
         (let (pos)
           (ppcre:do-scans (start
                            end
                            reg-starts
                            reg-ends
                            scanner
                            (current-line-string)
                            nil
                            :start (current-charpos))
             (setq pos start))
           pos))
     #'(lambda () (forward-line -1))
     #'set-charpos
     (search-backward-endp-function limit))))

(defun search-symbol-positions (name &key start end)
  (let ((positions)
        (str (current-line-string)))
    (ppcre:do-scans (start-var
                     end-var
                     reg-starts
                     reg-ends
                     "[a-zA-Z0-9+\\-<>/*&=.?_!$%:@\\[\\]^{}]+"
                     str nil
                     :start start :end end)
      (let ((str (subseq str start-var end-var)))
        (when (equal str name)
          (push (cons start-var end-var) positions))))
    (nreverse positions)))

(defun search-forward-symbol (name &optional limit)
  (search-step
   #'(lambda ()
       (cdar (search-symbol-positions name :start (current-charpos))))
   #'(lambda ()
       (cdar (search-symbol-positions name)))
   #'forward-line
   #'set-charpos
   (search-forward-endp-function limit)))

(defun search-backward-symbol (name &optional limit)
  (search-step
   #'(lambda ()
       (caar (last (search-symbol-positions name :end (current-charpos)))))
   #'(lambda ()
       (caar (last (search-symbol-positions name))))
   #'(lambda () (forward-line -1))
   #'set-charpos
   (search-backward-endp-function limit)))

(defun looking-at-line (regex &key (start nil startp) (end nil endp))
  (macrolet ((m (&rest args)
                `(ppcre:scan regex
                             (current-line-string)
                             ,@args)))
    (cond ((and startp endp)
           (m :start start :end end))
          (startp
           (m :start start))
          (endp
           (m :end end))
          (t
           (m)))))
