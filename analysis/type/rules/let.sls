(library (scheme-langserver analysis type rules let)
  (export let-process)
  (import 
    (chezscheme) 
    (ufo-match)

    (scheme-langserver util try)
    (scheme-langserver util cartesian-product)

    (scheme-langserver analysis identifier reference)
    (scheme-langserver analysis type util)
    (scheme-langserver analysis type walk-engine)

    (scheme-langserver virtual-file-system index-node)
    (scheme-langserver virtual-file-system document)
    (scheme-langserver virtual-file-system file-node))

(define (let-process document index-node substitutions)
  (let* ([ann (index-node-datum/annotations index-node)]
      [expression (annotation-stripped ann)]
      [children (index-node-children index-node)])
    (try
      (match expression
        [('let (? symbol? loop-identifier) (((? symbol? identifier) value ) ... ) _ **1) 
          (guard-for document index-node 'let '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
          (let* ([return-index-node (car (reverse children))]
              [return-variable (index-node-variable return-index-node)]

              ;((? symbol? identifier) value ) index-nodes
              [key-value-index-nodes (index-node-children (caddr children))]
              ;identifier index-nodes
              [key-index-nodes (map car (map index-node-children key-value-index-nodes))]
              [parameter-variable-products (construct-parameter-variable-products-with substitutions key-index-nodes)]

              ;(? symbol? loop-identifier)
              [loop-index-node (cadr children)]
              [loop-variable (index-node-variable loop-index-node)]
              ;((return-variable (parameter-variable ...)) **1)
              [loop-procedure-details (construct-lambdas-with `(,return-variable) parameter-variable-products)])
            (fold-left
              add-to-substitutions
              substitutions 
              ;for let index-node
              (append 
                (construct-substitutions-between-index-nodes substitutions index-node return-index-node '=)
                (construct-substitutions-between-index-nodes substitutions return-index-node index-node '=)
              ;for loop procedure
                (map 
                  (lambda (product)
                    `(,(car product) = ,(cadr product)))
                  (cartesian-product `(,loop-variable) loop-procedure-details))
              ;for key value index-nodes
                (apply append (map (lambda (key-value-index-node) (private-process-key-value substitutions key-value-index-node)) key-value-index-nodes)))))]
        [('let (((? symbol? identifier) value) ...) _ **1) 
          (guard-for document index-node 'let '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
          (let* ([return-index-node (car (reverse children))]

              ;((? symbol? identifier) value ) index-nodes
              [key-value-index-nodes (index-node-children (cadr children))])
            (fold-left
              add-to-substitutions
              substitutions 
              ;for let index-node
              (append 
                (construct-substitutions-between-index-nodes substitutions index-node return-index-node '=)
                (construct-substitutions-between-index-nodes substitutions return-index-node index-node '=)
              ;for key value index-nodes
                (apply append (map (lambda (key-value-index-node) (private-process-key-value substitutions key-value-index-node)) key-value-index-nodes)))))]
        ; [('fluid-let (((? symbol? identifier) no-use ... ) **1 ) _ ... ) 
        ;   (guard-for document index-node 'fluid-let '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
        ;   (let loop ([rest (index-node-children (cadr (index-node-children index-node)))])
        ;     (if (not (null? rest))
        ;       (let* ([identifier-parent-index-node (car rest)]
        ;             [identifier-index-node (car (index-node-children identifier-parent-index-node))])
        ;         (index-node-excluded-references-set! 
        ;           identifier-parent-index-node
        ;           (append 
        ;             (index-node-excluded-references identifier-parent-index-node)
        ;             (private-process identifier-index-node index-node '() document 'variable)))
        ;         (loop (cdr rest)))))]
        ; [('fluid-let-syntax (((? symbol? identifier) no-use ... ) **1 ) _ ... ) 
        ;   (guard-for document index-node 'fluid-let '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
        ;   (let loop ([rest (index-node-children (cadr (index-node-children index-node)))])
        ;     (if (not (null? rest))
        ;       (let* ([identifier-parent-index-node (car rest)]
        ;             [identifier-index-node (car (index-node-children identifier-parent-index-node))])
        ;         (index-node-excluded-references-set! 
        ;           identifier-parent-index-node
        ;           (append 
        ;             (index-node-excluded-references identifier-parent-index-node)
        ;             (private-process identifier-index-node index-node '() document 'syntax-variable)))
        ;         (loop (cdr rest)))))]
        ; [('let-syntax (((? symbol? identifier) no-use ... ) **1 ) _ ... ) 
        ;   (guard-for document index-node 'let-syntax '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
        ;   (let loop ([rest (index-node-children (cadr (index-node-children index-node)))])
        ;     (if (not (null? rest))
        ;       (let* ([identifier-parent-index-node (car rest)]
        ;             [identifier-index-node (car (index-node-children identifier-parent-index-node))])
        ;         (index-node-excluded-references-set! 
        ;           identifier-parent-index-node
        ;           (append 
        ;             (index-node-excluded-references identifier-parent-index-node)
        ;             (private-process identifier-index-node index-node '() document 'syntax-variable)))
        ;         (loop (cdr rest)))))]
        ; [('let-values (((? symbol? identifier) no-use ... ) **1 ) _ ... ) 
        ;   (guard-for document index-node 'let-values '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
        ;   (let loop ([rest (index-node-children (cadr (index-node-children index-node)))])
        ;     (if (not (null? rest))
        ;       (let* ([identifier-parent-index-node (car rest)]
        ;             [identifier-index-node (car (index-node-children identifier-parent-index-node))])
        ;         (index-node-excluded-references-set! 
        ;           identifier-parent-index-node
        ;           (append 
        ;             (index-node-excluded-references identifier-parent-index-node)
        ;             (private-process identifier-index-node index-node '() document 'syntax-variable)))
        ;         (loop (cdr rest)))))]
        [('let* (((? symbol? identifier) value) ... ) _ **1 ) 
          (guard-for document index-node 'let* '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
          (let* ([return-index-node (car (reverse children))]

              ;((? symbol? identifier) value ) index-nodes
              [key-value-index-nodes (index-node-children (cadr children))])
            (fold-left
              add-to-substitutions
              substitutions 
              ;for let index-node
              (append 
                (construct-substitutions-between-index-nodes substitutions index-node return-index-node '=)
                (construct-substitutions-between-index-nodes substitutions return-index-node index-node '=)
              ;for key value index-nodes
                (apply append (map (lambda (key-value-index-node) (private-process-key-value substitutions key-value-index-node)) key-value-index-nodes)))))]
        ; [('let*-values (((? symbol? identifier) no-use ... ) **1 ) _ ... ) 
        ;   (guard-for document index-node 'let*-values '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
        ;   (let loop ([include '()] 
        ;         [rest (index-node-children (cadr (index-node-children index-node)))])
        ;     (if (not (null? rest))
        ;       (let* ([identifier-parent-index-node (car rest)]
        ;             [identifier-index-node (car (index-node-children identifier-parent-index-node))]
        ;             [reference-list (private-process identifier-index-node index-node '() document 'variable)])
        ;         (index-node-excluded-references-set! 
        ;           identifier-parent-index-node
        ;           (append 
        ;             (index-node-excluded-references identifier-parent-index-node)
        ;             reference-list))
        ;         (index-node-references-import-in-this-node-set! 
        ;           identifier-parent-index-node
        ;           (append 
        ;             (index-node-references-import-in-this-node identifier-parent-index-node)
        ;             include))
        ;         (loop (append include reference-list) (cdr rest)))))]
        [('letrec (((? symbol? identifier) value ) ... ) _ **1) 
          (guard-for document index-node 'letrec '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
          (let* ([return-index-node (car (reverse children))]

              ;((? symbol? identifier) value ) index-nodes
              [key-value-index-nodes (index-node-children (cadr children))])
            (fold-left
              add-to-substitutions
              substitutions 
              ;for let index-node
              (append
                (construct-substitutions-between-index-nodes substitutions index-node return-index-node '=)
                (construct-substitutions-between-index-nodes substitutions return-index-node index-node '=)
              ;for key value index-nodes
                (apply append (map (lambda (key-value-index-node) (private-process-key-value substitutions key-value-index-node)) key-value-index-nodes)))))]
        [('letrec-syntax (((? symbol? identifier) value) ... ) _ **1) 
          (guard-for document index-node 'letrec-syntax '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
          (let* ([return-index-node (car (reverse children))]

              ;((? symbol? identifier) value ) index-nodes
              [key-value-index-nodes (index-node-children (cadr children))])
            (fold-left
              add-to-substitutions
              substitutions 
              ;for let index-node
              (append 
                (construct-substitutions-between-index-nodes substitutions index-node return-index-node '=)
                (construct-substitutions-between-index-nodes substitutions return-index-node index-node '=)
              ;for key value index-nodes
                (apply append (map (lambda (key-value-index-node) (private-process-key-value substitutions key-value-index-node)) key-value-index-nodes)))))]
        [('letrec* (((? symbol? identifier) value) ...) _ **1) 
          (guard-for document index-node 'letrec* '(chezscheme) '(rnrs) '(rnrs base) '(scheme))
          (let* ([return-index-node (car (reverse children))]

              ;((? symbol? identifier) value ) index-nodes
              [key-value-index-nodes (index-node-children (cadr children))])
            (fold-left
              add-to-substitutions
              substitutions 
              ;for let index-node
              (append 
                (construct-substitutions-between-index-nodes substitutions index-node return-index-node '=)
                (construct-substitutions-between-index-nodes substitutions return-index-node index-node '=)
              ;for key value index-nodes
                (apply append (map (lambda (key-value-index-node) (private-process-key-value substitutions key-value-index-node)) key-value-index-nodes)))))]
        [else substitutions])
      (except c
        [else substitutions]))))

(define (private-process-key-value substitutions parent-index-node)
  (let* ([ann (index-node-datum/annotations parent-index-node)]
      [expression (annotation-stripped ann)]
      [children (index-node-children parent-index-node)])
    (match expression 
      [((? symbol? left) value) (construct-substitutions-between-index-nodes substitutions (car children) (cadr children) '=)]
      [else '()])))
)
