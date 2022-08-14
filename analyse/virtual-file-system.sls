(library (scheme-langserver analyse virtual-file-system)
  (export 
    file-node?
    file-node-children
    file-node-folder?
    file-node-parent
    file-node-name
    file-node-path
    init-virtual-file-system 
    folder-or-scheme-file?)
  (import 
    (chezscheme) 
    (scheme-langserver util path)
    (only (srfi :13 strings) string-prefix? string-suffix?))

(define-record-type file-node 
  (fields
  ; https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#initialize
  ;; 有个root-uri属性
    (immutable path)
    (immutable name)
    (immutable parent)
    (immutable folder?)
    (mutable children)
  ))

(define (init-virtual-file-system path parent my-filter)
  (if (my-filter path)
    (let* ([name (path->name path)] 
          [folder? (file-directory? path)]
          [node (make-file-node path name parent folder? '())]
          [children (if folder?
              (map 
                (lambda(p) 
                  (init-virtual-file-system 
                    (string-append path (list->string (list (directory-separator))) p) 
                    node 
                    my-filter)) 
                (directory-list path))
              '())])
      (file-node-children-set! node (filter (lambda(p) (not (null? p))) children))
      node)
    '()))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (walk to-path from-node)
  (if from-node
    (let ([current-path (file-node-path from-node)])
      (if (string-prefix? current-path to-path)
        (if (equal? to-path current-path)
          from-node
          (walk to-path 
            (find (lambda (child) (string-suffix? (file-node-path child) to-path)) 
              (file-node-children from-node))))))))

(define (folder-or-scheme-file? path)
  (if (file-directory? path) 
    #t
    (find (lambda(t) (or t #f))
      (map (lambda (suffix) (string-suffix? suffix path)) 
      '(".sps" ".sls" ".scm" ".ss")))))
)