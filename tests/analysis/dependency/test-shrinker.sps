#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2022 WANG Zheng
;; SPDX-License-Identifier: MIT
#!r6rs

(import 
    ; (rnrs (6)) 
    (chezscheme)
    (srfi :64 testing) 
    (scheme-langserver virtual-file-system file-node)
    (scheme-langserver analysis workspace)
    (scheme-langserver analysis package-manager akku)
    (scheme-langserver analysis dependency shrinker)
    (scheme-langserver analysis dependency file-linkage))

(test-begin "test shrink-paths")
    (let* ([root-file-node (init-virtual-file-system (current-directory) '() akku-acceptable-file?)]
            [root-library-node (init-library-node root-file-node)]
            [file-linkage (init-file-linkage root-library-node)]
            [paths (get-init-reference-path file-linkage)])
        (pretty-print (file-linkage? file-linkage))
        (pretty-print (shrink-paths file-linkage paths))
        )
(test-end)


(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))
