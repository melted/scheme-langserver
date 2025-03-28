(library (scheme-langserver analysis type substitutions self-defined-rules ufo-match match)
  (export match-process)
  (import 
    (chezscheme) 
    (ufo-match)
    (ufo-try)
    (only (srfi :13) string-suffix?)

    (scheme-langserver util dedupe)
    (scheme-langserver util cartesian-product)

    (scheme-langserver analysis util)
    (scheme-langserver analysis identifier meta)
    (scheme-langserver analysis identifier reference)

    (scheme-langserver virtual-file-system index-node)
    (scheme-langserver virtual-file-system document))

(define (match-process document index-node)
  (let* ([ann (index-node-datum/annotations index-node)]
      [expression (annotation-stripped ann)])
    (try
      (match expression
        [(_ something **1)
          (fold-left 
            (lambda (prev i) 
              (let ([c (index-node-children i)])
                (append prev 
                  (if (not (null? c))
                    (private:pattern+scope document (car c) i)
                    '()))))
            '()
            (cdr (index-node-children index-node)))]
        [else '()])
      (except c
        [else '()]))))

(define (private:pattern+scope document pattern-index-node scope-index-node)
  (let* ([expression (annotation-stripped (index-node-datum/annotations pattern-index-node))]
      [children (index-node-children pattern-index-node)])
    (match expression 
      [('? something (? symbol? s)) 
        (let* ([s-index-node (car (reverse children))]
            [s-variable (index-node-variable s-index-node)]
            [pre-available-references (find-available-references-for document scope-index-node s)]
            [available-references (dedupe (apply append (map root-ancestor pre-available-references)))])
          (cartesian-product `(,s-variable) '(:) 
            (map construct-type-expression-with-meta 
              (map identifier-reference-identifier 
                (filter 
                  (lambda (r)
                    (and (null? (identifier-reference-index-node r)) (string-suffix? (symbol->string (identifier-reference-identifier r)) "?")))
                  available-references)))))]
      [else 
        (fold-left 
          (lambda (prev i) (append prev (private:pattern+scope document i scope-index-node)))
          '()
          children)])))
)