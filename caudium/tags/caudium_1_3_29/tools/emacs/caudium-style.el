;: -*- emacs-lisp -*-
;:* $Id$

;; Add the contents of this file to your (X)Emacs startup sequence
;; (~/.emacs, ~/.xemacs or ~/.xemacs/init.el) And this style will become
;; the default one for your C, C++ and Pike source files
;;
;; If you don't want it to be the default, you can comment out the
;; (add-hook) calls. If you do that, then the style will be in effect after
;; you do
;;
;;  M-x c-set-style RET caudium RET
;;
(defconst caudium-c-style
  '((c-basic-offset                . 2)    
    (c-tab-always-indent           . t)
    (c-comment-only-line-offset    . 0)
    (c-hanging-braces-alist        . ((substatement-open after)
                                      (brace-list-open after)
                                      (brace-list-close after)
                                      (brace-list-intro before)
                                      (brace-entry-open before)
                                      (class-open before after)
                                      (class-close before after)
                                      (defun-open before after)
                                      (defun-close before after)
                                      (block-open before after)
                                      (block-close before after)
                                      (substatement-open after)
                                      (statement-case-open after)
                                      (extern-lang-open before after)
                                      (extern-lang-close before after)))
    (c-hanging-colons-alist        . ((member-init-intro before)
                                      (inher-intro)
                                      (case-label after)
                                      (label after)
                                      (access-label after)))
    (c-cleanup-list                . (brace-else-brace
                                      brace-elseif-brace
                                      brace-catch-brace
                                      empty-defun-braces
                                      scope-operator
                                      defun-close-semi
                                      list-close-comma))
    (c-offsets-alist               . ((arglist-close       . c-lineup-close-paren)
                                      (inclass             . +)
                                      (substatement-open   . 0)
                                      (access-label        . -2)
                                      (case-label          . 4)
                                      (block-open          . 0)
                                      (inline-open         . 0)
                                      (topmost-intro       . 0)
                                      (defun-block-intro   . +)
                                      (statement           . 0)
                                      (arglist-intro       . c-lineup-arglist-intro-after-paren)
                                      (arglist-cont-nonempty . c-lineup-arglist)
                                      (stream-op           . c-lineup-streamop)
                                      (knr-argdecl-intro   . -)))
    (c-echo-syntactic-information-p . t)
    )
  "Caudium C&Pike Style")

(defun caudium-c-mode-common-hook ()
  (c-add-style "caudium" caudium-c-style t)
  (c-set-style "caudium")
  (c-set-offset 'member-init-intro '++)
  (setq tab-width 2)
  (setq indent-tabs-mode nil)
  (c-toggle-auto-hungry-state 1)
  (auto-fill-mode 1)
  (setq c-enable-xemacs-performance-kludge-p nil)
  (setq c-tab-always-indent 'other)
  (define-key c-mode-base-map "\C-m" 'newline-and-indent)
  (message "Caudium C mode set"))
(add-hook 'c-mode-common-hook 'caudium-c-mode-common-hook)

(defun caudium-c-mode-hook ()
  ;; This is optional, but it adds nice support for highlighting 
  ;; custom-defined C/Pike types 
  (require 'ctypes)
  (turn-on-font-lock)
  (setq ctypes-write-types-at-exit t)
  (ctypes-read-file nil nil t t)
  (ctypes-auto-parse-mode 1))
(add-hook 'c-mode-hook 'caudium-c-mode-hook)
(add-hook 'c++-mode-hook 'caudium-c-mode-hook)
