#lang racket

(provide (all-defined-out))

(define DOMAIN "your domain")
(define OUTPACE-TEAM-ID "slack team id")
(define SLACK-CLIENT-ID "your slack application client id")
(define SLACK-CLIENT-SECRET "your slack application client secret")

(define SERVER-PATHS (list "/path/to/your/presentations/outpace_lyat"))
(define WHITE-CARDS (file->lines "white-cards.txt"))
(define BLACK-CARDS (file->lines "black-cards.txt"))
