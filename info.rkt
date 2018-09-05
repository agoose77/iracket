#lang info

;; ========================================
;; pkg info

(define collection "iracket")
(define deps
  '("base"
    "zeromq-r-lib"
    "sandbox-lib"
    "libuuid"
    "sha"))
(define build-deps
  '("racket-doc"
    "scribble-lib"))

;; ========================================
;; collect info

(define name "iracket")
;; (define scribblings '(["iracket.scrbl" ()]))

;; Doesn't actually do installation, just prints message.
(define install-collection "command.rkt")

(define raco-commands
  '(("iracket" (submod iracket/command raco) "manage IRacket (Jupyter support)" #f)))
