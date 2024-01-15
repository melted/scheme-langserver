#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2022 WANG Zheng
;; SPDX-License-Identifier: MIT
#!r6rs

(import 
    (rnrs (6)) 
    (srfi :64 testing) (scheme-langserver util dedupe))

(test-begin "dedupe")
    (test-equal '(1) (dedupe '(1)))
    (test-equal '(1) (dedupe '(1 1)))
    (test-equal '(1 2) (dedupe '(1 2 1)))
(test-end)

(test-begin "ordered-dedupe")
    (test-equal '(1) (ordered-dedupe '(1)))
    (test-equal '(1) (ordered-dedupe '(1 1)))
    (test-equal '(1 2) (dedupe '(1 1 2)))
(test-end)

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))
