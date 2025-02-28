(defpackage :lem-vi-mode/window
  (:use :cl
        :lem)
  (:import-from :lem-vi-mode/options
                :option-value)
  (:import-from :lem-core
                :window-height-without-modeline)
  (:export :move-to-window-top
           :move-to-window-middle
           :move-to-window-bottom
           :adjust-window-scroll))
(in-package :lem-vi-mode/window)

(defun window-height* (&optional (window (current-window)))
  (window-height-without-modeline window))

(defun scroll-offset (&optional (window (current-window)))
  (min (floor (/ (window-height* window) 2))
       (option-value "scrolloff")))

(defun window-start-point (&optional (window (current-window)))
  (window-view-point window))

(defun window-end-point (&optional (window (current-window)))
  (let ((point (copy-point (window-start-point window))))
    (move-to-next-virtual-line point (1- (window-height* window)) window)
    point))

(defun window-has-following-lines-p (&optional (window (current-window)))
  (let ((end-point (window-end-point window)))
    (with-point ((p end-point))
      (move-to-next-virtual-line p)
      (and (point/= p end-point)
           (point/= p (buffer-end-point (window-buffer window)))))))

(defun window-has-leading-lines-p (&optional (window (current-window)))
  (let ((start-point (window-start-point window)))
    (or (< 1 (line-number-at-point start-point))
        (/= 0 (point-charpos start-point)))))

(defun move-to-window-top ()
  (let ((window (current-window)))
    (move-point (current-point) (window-start-point window))
    (when (window-has-leading-lines-p window)
      (next-line (scroll-offset)))))

(defun move-to-window-middle ()
  (let ((window (current-window)))
    (move-point (current-point) (window-start-point window))
    (next-line (floor (/ (- (window-height* window) 2) 2)))))

(defun move-to-window-bottom ()
  (let ((window (current-window)))
    (move-point (current-point) (window-end-point window))
    (when (window-has-following-lines-p window)
      (previous-line (scroll-offset)))))

(defun adjust-window-scroll ()
  (let* ((window (current-window))
         (window-height (window-height* window))
         (cursor-y (window-cursor-y window))
         (scroll-offset (scroll-offset window)))
    (cond
      ((< cursor-y scroll-offset)
       (window-scroll window (- cursor-y scroll-offset)))
      ((and (<= (- window-height scroll-offset) cursor-y)
            (window-has-following-lines-p window))
       (window-scroll window (1+ (- cursor-y (- window-height scroll-offset))))))))
