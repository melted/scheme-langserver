(library (scheme-langserver virtual-file-system document)
  (export 
    make-document
    document?
    document-uri
    document-text
    document-text-set!
    document-index-node-list
    document-index-node-list-set!
    document-reference-list
    document-reference-list-set!
    document-substitution-list
    document-substitution-list-set!

    is-ss/scm?)
  (import (rnrs)
    (only (srfi :13 strings) string-prefix? string-suffix?))

(define-record-type document 
  (fields 
    (immutable uri)
    (mutable text)
    (mutable index-node-list)
    (mutable reference-list)
    (mutable substitution-list))
  (protocol
    (lambda (new)
      (lambda (uri text index-node-list reference-list)
        (new uri text index-node-list reference-list '())))))

(define (is-ss/scm? document)
  (map 
    (lambda (suffix) (string-suffix? suffix (document-uri document))) 
    '(".scm" ".ss")))
)
