#lang racket/base
(require (for-syntax racket/base)
         racket/cmdline
         raco/command-name
         racket/match
         racket/string
         racket/file
         racket/port
         racket/system
         racket/runtime-path)

;; Script for configuring iracket.

;; TODO:
;; - add c3 support installation
;; - uninstallation?

(define-runtime-path iracket-dir ".")
(define-runtime-path kernel-path "static/kernel.json")
(define-runtime-path-list js-paths (list "static/custom.js" "static/c3.js"))
(define *use-jupyter-dir* (make-parameter #f))

(define (get-jupyter-exe [fail-ok? #f])
  (or (find-executable-path "jupyter")
      (if fail-ok? #f (raise-user-error "Cannot find jupyter executable."))))

(define (get-jupyter-dir [fail-ok? #f])
  (or (*use-jupyter-dir*)
      (let ([jupyter (get-jupyter-exe fail-ok?)])
        (cond [jupyter
               (string-trim
                (with-output-to-string
                  (lambda () (system*/exit-code jupyter "--data-dir"))))]
              [fail-ok? #f]
              [else (raise-user-error "Cannot find jupyter data directory.")]))))

(define (get-racket-kernel-dir [fail-ok? #f])
  (define jupyter-dir (get-jupyter-dir fail-ok?))
  (and jupyter-dir (build-path jupyter-dir "kernels" "racket")))

;; ============================================================
;; Commands

;; ----------------------------------------
;; Install kernel

(define (cmd:install args)
  (command-line
   #:program (short-program+command-name)
   #:argv args
   #:once-any
   [("--jupyter-dir") dir
    "Write to given jupyter data directory" ;; (normally `jupyter --data-dir`)
    (*use-jupyter-dir* dir)]
   #:args ()
   (write-iracket-kernel-json!)))

(define (write-iracket-kernel-json!)
  (define racket-kernel-dir
    (or (get-racket-kernel-dir)
        (raise-user-error "Cannot find jupyter data directory; try --jupyter-dir")))
  (make-directory* racket-kernel-dir)
  (define kernel-json
    (regexp-replace* (regexp-quote "IRACKET_SRC_DIR")
                     (file->string kernel-path)
                     (path->string iracket-dir)))
  (define dest-file (build-path racket-kernel-dir "kernel.json"))
  (when (file-exists? dest-file)
    (printf "Replacing old ~s\n" (path->string dest-file)))
  (with-output-to-file dest-file #:exists 'truncate/replace
    (lambda () (write-string kernel-json)))
  (printf "Kernel json file copied to ~s\n" (path->string dest-file)))

;; ----------------------------------------
;; Help

(define (cmd:help _args)
  (printf "Usage: ~a <command> <option> ... <arg> ...\n\n"
          (short-program+command-name))
  (printf "Commands:\n")
  (define command-field-width
    (+ 4 (apply max 12 (map string-length (map car subcommand-handlers)))))
  (for ([subcommand (in-list subcommand-handlers)])
    (match-define (list command _ help-text) subcommand)
    (define pad (make-string (- command-field-width (string-length command)) #\space))
    (printf "  ~a~a~a\n" command pad help-text)))

;; ============================================================
;; Main (command dispatch)

(define subcommand-handlers
  `(("help"    ,cmd:help     "show help")
    ("install" ,cmd:install  "register IRacket kernel with Jupyter")))

(define (call-subcommand handler name args)
  (parameterize ((current-command-name
                  (cond [(current-command-name)
                         => (lambda (prefix) (format "~a ~a" prefix name))]
                        [else #f])))
    (handler args)))

(module+ raco
  (define args (vector->list (current-command-line-arguments)))
  (cond [(and (pair? args) (assoc (car args) subcommand-handlers))
         => (lambda (p) (call-subcommand (cadr p) (car args) (cdr args)))]
        [else (cmd:help args)]))

;; ============================================================
;; raco setup hook

(provide installer)

(define (installer _parent _here _user? _inst?)
  (define kernel-dir (get-racket-kernel-dir))
  (define kernel-path (and kernel-dir (build-path kernel-dir "kernel.json")))
  (cond [(and kernel-path (file-exists? kernel-path))
         (when #f
           (printf "IRacket kernel found in ~a.\n" (path->string kernel-dir)))]
        [else
         (printf "\n***\n")
         (printf "*** IRacket must register its kernel with jupyter before it can be used.\n")
         (printf "*** Run `raco iracket install` to finish installation.\n")
         (printf "***\n\n")]))
