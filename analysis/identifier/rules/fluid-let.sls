(library (scheme-langserver analysis identifier rules fluid-let)
  (export 
    fluid-let-process
    fluid-let-parameter-process
    )
  (import 
    (chezscheme) 
    (ufo-match)

    (scheme-langserver util try)

    (scheme-langserver analysis identifier reference)

    (scheme-langserver virtual-file-system index-node)
    (scheme-langserver virtual-file-system library-node)
    (scheme-langserver virtual-file-system document)
    (scheme-langserver virtual-file-system file-node))

; reference-identifier-type include 
; variable 
(define (fluid-let-process root-file-node root-library-node document index-node)
  (let* ([ann (index-node-datum/annotations index-node)]
      [expression (annotation-stripped ann)])
    (try
      (match expression
        [(_ (((? symbol? identifier) no-use ... ) **1 ) fuzzy ... ) 
          (fold-left 
            (lambda (exclude-list identifier-parent-index-node)
              (let* ([identifier-index-node (car (index-node-children identifier-parent-index-node))]
                  [extended-exclude-list 
                    (append exclude-list (fluid-let-parameter-process index-node identifier-index-node index-node exclude-list document 'variable))])
                (index-node-excluded-references-set! (index-node-parent identifier-parent-index-node) extended-exclude-list)
                extended-exclude-list))
            '()
            (index-node-children (cadr (index-node-children index-node))))]
        [else '()])
      (except c
        [else '()]))))

(define (fluid-let-parameter-process initialization-index-node index-node let-node exclude document type)
  (let* ([ann (index-node-datum/annotations index-node)]
      [expression (annotation-stripped ann)]
      [upper (find-available-references-for document index-node expression)]
      [reference 
        (make-identifier-reference
          expression
          document
          index-node
          initialization-index-node
          '()
          type
          upper
          '())])

    (if (not (null? upper))
      (begin
        (index-node-references-export-to-other-node-set! 
          index-node
          (append 
            (index-node-references-export-to-other-node index-node)
              `(,reference)))

        (append-references-into-ordered-references-for document let-node `(,reference))

        `(,reference))
      '())))
)
