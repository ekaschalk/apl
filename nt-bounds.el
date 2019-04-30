;;; nt-bounds.el --- Indent Boundaries -*- lexical-binding: t; -*-

;; Copyright © 2019 Eric Kaschalk <ekaschalk@gmail.com>

;;; Commentary:

;; Calculate boundaries of notes effects on indentation masks. Major-mode
;; dependent functions are implemented here.

;; Other modules should only be interested in `nt-bound' and `nt-bound?'

;;; Code:
;;;; Requires

(require 'nt-base)

(require 'nt-ov)

;;; Exposes

(defun nt-bound (note)
  "Call `nt-bound-fn' on NOTE."
  (funcall (symbol-value #'nt-bound-fn) note))

(defun nt-bound? (note)
  "Call `nt-bound?-fn' on NOTE."
  (funcall (symbol-value #'nt-bound?-fn) note))

;;; Language Agnostic

(defun nt-bounds?--in-string-or-comment? (note)
  "Is NOTE contained within a string or comment?"
  (let ((state (save-excursion
                 (syntax-ppss (overlay-start note)))))
    (or (nth 3 state) (nth 4 state))))

;;; Lisps - Emacs Lisp Only

(defun nt-bounds?--elisp-indent-declared? (note)
  "Returns non-nil if indendation declarations are attached to NOTE."
  (-some-> note nt-ov->symbol (function-get 'lisp-indent-function)))

;;; Lisps - General
;;;; Predicates
;;;;; Components

(defun nt-bounds?--ignore? (note)
  "Should NOTE never contribute to indentation?"
  (-contains? nt-ignore-notes (nt-ov->string note)))

(defun nt-bounds?--lisps-terminal-sexp? (note)
  "Is NOTE the terminal sexp on its line?

(note
 foo)

Does not have NOTE contributing to indentation masks though it is a form opener.
"
  (save-excursion
    (nt-ov--goto note)

    (let ((line-start (line-number-at-pos)))
      (ignore-errors (forward-sexp) (forward-sexp))
      (< line-start (line-number-at-pos)))))

(defun nt-bounds?--lisps-another-form-opener-on-line? (note)
  "Does NOTE have another form opener on the same line?

(foo note (foo foo
               foo))

Has NOTE contributing to indentation masks even though it is not a form opener.
"
  (save-excursion
    (let ((line-start (line-number-at-pos))
          (depth (nt--depth-at-point)))

      (sp-down-sexp)

      (let ((descended? (> (nt--depth-at-point) depth))
            (same-line? (= line-start (line-number-at-pos))))
        (and descended? same-line?)))))

(defun nt-bounds?--lisps-form-opener? (note)
  "Does NOTE open a form?

(note foo
      bar)

Simplest case that has NOTE contributing to indentation masks."
  (save-excursion
    (nt-ov--goto note)
    (null (ignore-errors (backward-sexp) t))))

;;;;; Composed

(defun nt-bounds?--lisps (note)
  "Render NOTE's indentation boundary? If so give NOTE."
  ;; Not optimized obviously, focusing on easy testing of components
  (let* ((fail-predicates '(nt-bounds?--ignore?
                            nt-bounds?--in-string-or-comment?
                            nt-bounds?--elisp-indent-declared?
                            nt-bounds?--lisps-terminal-sexp?))
         (pass-predicates '(nt-bounds?--lisps-another-form-opener-on-line?
                            nt-bounds?--lisps-form-opener?))
         (any-fail? (apply #'-orfn fail-predicates))
         (any-pass? (apply #'-orfn pass-predicates)))
    (when (and (not (funcall any-fail? note))
               (funcall any-pass? note))
      note)))

;;;; Boundary

(defun nt-bounds--lisps (note)
  "Calculate line boundary [a b) for NOTE's masks."
  (save-excursion
    (nt-ov--goto note)
    (sp-end-of-sexp)
    (1+ (line-number-at-pos))))

;;; Generalized
;;;; Commentary

;; Special indent rules, indent blocks, etc. will be handled by
;; major-mode-dependent predicate. I don't think the predicate can be made
;; major-mode-agnostic...

;; Still thinking about the bound is nil case
;;   ie. all lines are empty/before indent and so are bound
;; An option is to signal that the bound is being completed still.
;; Depending on how change functions are implemented, I may use this idea

;;;; Implementation

;; TODO Not compatabile yet with `after-change-functions'
;; however, it works without them enabled.
(defun nt-bounds--general (note)
  "Generalized visual-line based bounds finding for NOTE."
  (save-excursion
    (nt-ov--goto note)

    (let ((start-line (line-number-at-pos))
          (bound (line-number-at-pos (point-max))))
      (nt-line-move-visual-while (or (nt-line--empty? line)
                                     (nt--before-indent?))
        (when (nt-line--nonempty? line)
          (setq bound line)))

      (1+ bound))))

;;; Provide

(provide 'nt-bounds)

;;; nt-bounds.el ends here
