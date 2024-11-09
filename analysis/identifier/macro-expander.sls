(library (scheme-langserver analysis identifier macro-expander)
  (export 
    expand:step-by-step
    expand:step-by-step-identifier-reference
    generate-pair:template+callee
    generate-pair:template+expanded)
  (import 
    (chezscheme)
    (ufo-match)

    (scheme-langserver util try)
    (scheme-langserver util path)
    (scheme-langserver util dedupe)
    (scheme-langserver util contain)
    (scheme-langserver util cartesian-product)

    (scheme-langserver analysis tokenizer)
    (scheme-langserver analysis local-expand)

    (scheme-langserver analysis identifier util)
    (scheme-langserver analysis identifier meta)
    (scheme-langserver analysis identifier reference)

    (scheme-langserver virtual-file-system index-node)
    (scheme-langserver virtual-file-system library-node)
    (scheme-langserver virtual-file-system document)
    (scheme-langserver virtual-file-system file-node))

(define (expand:step-by-step-identifier-reference identifier-reference callee-index-node callee-document)
  (map 
    (lambda (p)
      (let* ([target-index-node (cdr p)]
          [identifier-reference (car p)])
        `(,identifier-reference . ,(private:dispatch (cdr p) callee-index-node callee-document))))
    (private:unwrap identifier-reference)))

(define (expand:step-by-step identifier-reference callee-index-node callee-document)
  (map cdr (expand:step-by-step-identifier-reference identifier-reference callee-index-node callee-document)))

(define (generate-pair:template+expanded identifier-reference expanded-index-node callee-index-node callee-document template+callees)
  (fold-left 
    (lambda (left maybe-pair)
      (let* ([head (car maybe-pair)]
          [tail (cdr maybe-pair)]
          [prev-pair (assq head left)])
        (if prev-pair
          (append (filter (lambda (p) (not (eq? head (car p)))) left)
            (if (index-node? (cdr prev-pair))
              `((,head . (,(cdr prev-pair) ,tail)))
              `((,head . (,@(cdr prev-pair) ,tail)))))
          (append left (list maybe-pair)))))
    '()
    (apply append 
      (map 
        (lambda (p)
          (private:dispatch-for-expanded-pair (cdr p) callee-index-node callee-document expanded-index-node template+callees))
        (private:unwrap identifier-reference)))))

(define (generate-pair:template+callee identifier-reference callee-index-node callee-document)
  (fold-left 
    (lambda (left maybe-pair)
      (let* ([head (car maybe-pair)]
          [tail (cdr maybe-pair)]
          [prev-pair (find (lambda (l) (equal? head (car l))) left)]
          [head... `(,head ...)]
          [prev-pair... (find (lambda (l) (equal? head... (car l))) left)])
        (cond 
          [prev-pair...
            (append 
              (filter (lambda (p) (not (equal? head... (car p)))) left)
              `((,head... . (,@(cdr prev-pair...) ,tail))))]
          [prev-pair 
            (append 
              (filter (lambda (p) (not (equal? head (car p)))) left)
              `((,head... . (,(cdr prev-pair) ,tail))))]
          [else (append left (list maybe-pair))]
        )))
    '()
    (apply append 
      (map 
        (lambda (p)
          (private:dispatch-for-callee-pair (cdr p) callee-index-node callee-document))
        (private:unwrap identifier-reference)))))

(define (private:dispatch-for-expanded-pair index-node callee-index-node callee-document expanded-index-node template+callees)
  (let* ([expression (annotation-stripped (index-node-datum/annotations index-node))]
      [children (index-node-children index-node)]
      [first-child (car children)]
      [callee-expression (annotation-stripped (index-node-datum/annotations callee-index-node))]
      [expanded-expression (annotation-stripped (index-node-datum/annotations expanded-index-node))]
      [callee-index-nodes (index-node-children callee-index-node)])
    (match expression
      [(syntax-rules-head (keywords ...) clauses **1) 
        (if (root-meta-check callee-document first-child 'syntax-rules)
          (let* ([clause-index-nodes (cddr children)]
            [template (eval `(syntax-case ',callee-expression ,keywords ,@(map private:get-specific-template clauses)))]
            [body-index-node (private:get-specific-body-index-node clause-index-nodes template)]
            [body-expression (annotation-stripped (index-node-datum/annotations body-index-node))])
            (private:template-variable+expanded body-index-node body-expression expanded-index-node template+callees callee-document #f))
          '())]
      [(lambda-head ((? symbol? parameter)) _ ... (syntax-case-head like-parameter (keywords ...) clauses))
        ;I can't guarentee
        ; (if (and 
        ;     (equal? parameter like-parameter)
        ;     (root-meta-check callee-document first-child 'lambda)
        ;     (root-meta-check callee-document (car (index-node-children (car (reverse children)))) 'syntax-case))
        ;   (let* ([template (eval `(syntax-case ',callee-expression ,keywords ,@(map private:get-specific-body clauses)))])
        ;     (private:template-variable+expanded template expanded-index-nodes expanded-expression))
        ;   '())
        '()
          ]
      [else '()])))

(define (private:dispatch-for-callee-pair index-node callee-index-node callee-document)
  (let* ([expression (annotation-stripped (index-node-datum/annotations index-node))]
      [children (index-node-children index-node)]
      [first-child (car children)]
      [callee-expression (annotation-stripped (index-node-datum/annotations callee-index-node))]
      [callee-index-nodes (index-node-children callee-index-node)])
    (match expression
      [(syntax-rules-head (keywords ...) clauses **1) 
        (if (root-meta-check callee-document first-child 'syntax-rules)
          (let* ([template (eval `(syntax-case ',callee-expression ,keywords ,@(map private:get-specific-template clauses)))])
            (private:template-variable+callee template callee-index-nodes callee-expression keywords))
          '())]
      [(lambda-head ((? symbol? parameter)) _ ... (syntax-case-head like-parameter (keywords ...) clauses))
        (if (and 
            (equal? parameter like-parameter)
            (root-meta-check callee-document first-child 'lambda)
            (root-meta-check callee-document (car (index-node-children (car (reverse children)))) 'syntax-case))
          (let* ([template (eval `(syntax-case ',callee-expression ,keywords ,@(map private:get-specific-template clauses)))])
            (private:template-variable+callee template callee-index-nodes callee-expression keywords))
          '())]
      [else '()])))

(define (private:get-specific-template clause) 
  (match clause
    [(template body ...) `(,template ',template)]
    [else '()]))

(define (private:get-specific-body clause) 
  (match clause
    [(template body ...) `(,template ',body)]
    [else '()]))

(define (private:get-specific-body-index-node clause-index-nodes target-template) 
  (fold-left
    (lambda (stop? clause-index-node)
      (if (not stop?)
        (let* ([clause (annotation-stripped (index-node-datum/annotations clause-index-node))]
            [template (car clause)]
            [children (index-node-children clause-index-node)])
          (case template 
            [target-template (car (reverse children))]
            [else stop?]))
        stop?))
    #f
    clause-index-nodes))

(define (private:template-variable+expanded body-index-node body-expression expanded-index-node template+callees document is-...?)
  (cond 
    [(and (private:syntax-parameter-index-node? body-index-node document body-expression) is-...? (assoc body-expression template+callees))
      `((,body-expression . ,expanded-index-node))]
    [(and (private:syntax-parameter-index-node? body-index-node document body-expression) is-...? (assoc `(body-expression ...) template+callees))
      (let ([v (list->vector (cdr (assoc `(body-expression ...) template+callees)))])
        (if (> (vector-length v) is-...?)
          `((,body-expression . ,expanded-index-node))
          '()))]
    ; [(and (private:syntax-parameter-index-node? body-index-node document body-expression) is-...?) (raise 'IdontKnowWhy)]
    [(and (private:syntax-parameter-index-node? body-index-node document body-expression) (assoc body-expression template+callees))
      `((,body-expression . ,expanded-index-node))]
    [(private:syntax-parameter-index-node? body-index-node document body-expression) (raise 'IdontKnowWhy)]
    [(symbol? body-expression) '()]

    [(and (not (symbol? body-expression)) (index-node? body-index-node)) 
      (private:template-variable+expanded (index-node-children body-index-node) body-expression (index-node-children expanded-index-node) template+callees document is-...?) ]
    [(vector? body-expression) 
      (private:template-variable+expanded body-index-node (vector->list body-expression) expanded-index-node template+callees document is-...?)]
    [(null? body-expression) '()]
    [(not (list? body-expression)) (private:template-variable+expanded body-index-node `(,(car body-expression) ,(cdr body-expression)) expanded-index-node template+callees document is-...?)]

    [(>= (length body-index-node) 2)
      (if (equal? (cadr body-expression) '...)
        (if is-...?
          (raise 'IdontKnowWhy)
          (let loop ([auto-increase 0])
            (let ([what-i-got
              (private:template-variable+expanded (car body-index-node) (car body-expression) (car expanded-index-node) template+callees document auto-increase)])
              (if (null? what-i-got)
                what-i-got
                (append what-i-got (loop (+ 1 auto-increase)))))))
        (append 
          (private:template-variable+expanded (car body-index-node) (car body-expression) (car expanded-index-node) template+callees document is-...?)
          (private:template-variable+expanded (cdr body-index-node) (cdr body-expression) (cdr expanded-index-node) template+callees document is-...?)))]
    [(list? body-expression) (private:template-variable+expanded body-index-node (car body-expression) expanded-index-node template+callees document is-...?)]))

(define (private:syntax-parameter-index-node? index-node document expression)
  (if (symbol? expression)
    (not
      (find 
        (lambda (x) (not (equal? 'syntax-parameter x)))
        (map identifier-reference-type (find-available-references-for index-node document expression)))))
    #f)

(define (private:template-variable+callee template callee-index-node callee-expression keywords)
  (cond 
    [(contain? keywords callee-expression) '()]
    [(symbol? template) `((,template . ,callee-index-node))]
    [(and (not (symbol? template)) (index-node? callee-index-node)) (private:template-variable+callee template (index-node-children callee-index-node) callee-expression keywords)]
    [(vector? template) (private:template-variable+callee (vector->list template) (index-node-children callee-index-node) (vector->list callee-expression) keywords)]
    [(null? template) '()]
    ;pair
    [(not (list? template)) (private:template-variable+callee `(,(car template) ,(cdr template)) callee-index-node `(,(car callee-expression) ,(cdr callee-expression)) keywords)]
    [(and (>= (length callee-index-node) 2))
      (if (equal? (cadr template) '...)
        (let* ([new-callee-expression (syntax->datum (eval `(syntax-case ',callee-expression ,keywords (,template #'(,(car template) ,(cadr template))))))]
            [size (length new-callee-expression)])
          (append 
            (apply append 
              (map 
                (lambda (l)
                  (private:template-variable+callee 
                    (car template) 
                    l
                    (annotation-stripped (index-node-datum/annotations l))
                    keywords))
                (list-head callee-index-node size)))
            (private:template-variable+callee 
              (list-tail template 2)
              (list-tail callee-index-node size)
              (list-tail callee-expression size)
              keywords)))
        (append 
          (private:template-variable+callee (car template) (car callee-index-node) (car callee-expression) keywords)
          (private:template-variable+callee (cdr template) (cdr callee-index-node) (cdr callee-expression) keywords)))]
    [(list? template) (private:template-variable+callee (car template) (car callee-index-node) (car callee-expression) keywords)]
    ))

(define (private:dispatch index-node callee-index-node callee-document)
  (let* ([expression (annotation-stripped (index-node-datum/annotations index-node))]
      [children (index-node-children index-node)]
      [first-child (car children)]
      [callee-expression (annotation-stripped (index-node-datum/annotations callee-index-node))])
    (match expression
      [(syntax-rules-head (keywords ...) clauses **1) 
        (if (root-meta-check callee-document first-child 'syntax-rules)
          (syntax->datum (eval `(syntax-case ',callee-expression ,keywords ,@(map private:rule-clause->case-clause clauses))))
          '())]
      [(lambda-head ((? symbol? parameter)) _ ... (syntax-case-head like-parameter (keywords ...) clauses))
        (if (and 
            (equal? parameter like-parameter)
            (root-meta-check callee-document first-child 'lambda)
            (root-meta-check callee-document (car (index-node-children (car (reverse children)))) 'syntax-case))
          (syntax->datum (eval `(_ ... (syntax-case ,like-parameter ,keywords ,@clauses))))
          '())]
      [else '()])))

(define (private:rule-clause->case-clause clause)
  (match clause
    [(template body) `(,template #',body)]
    [else '()]))

(define (private:unwrap identifier-reference)
  (let* ([initial (identifier-reference-initialization-index-node identifier-reference)]
      [initial-expression (annotation-stripped (index-node-datum/annotations initial))]
      [initial-children (index-node-children initial)]
      [first-child (car initial-children)]
      [first-child-expression (annotation-stripped (index-node-datum/annotations first-child))]
      [document (identifier-reference-document identifier-reference)]
      [first-child-identifiers (find-available-references-for document initial first-child-expression)]
      [first-child-top-identifiers (apply append (map root-ancestor first-child-identifiers))])
    (map 
      (lambda (first-child-identifier)
        (case (identifier-reference-identifier first-child-identifier)
          ['define-syntax `(,first-child-identifier . ,(caddr initial-children))]
          ['let-syntax `(,first-child-identifier . ,(cadr (index-node-parent (identifier-reference-index-node identifier-reference))))]))
      (filter (lambda (identifier) (meta-library? (identifier-reference-library-identifier identifier))) first-child-top-identifiers))))
)
