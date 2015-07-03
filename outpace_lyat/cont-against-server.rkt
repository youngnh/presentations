#lang racket
(require "config.rkt"
         json
         net/http-client
         net/rfc6455
         net/uri-codec
         web-server/servlet
         web-server/servlet-env)

(define black-deck (shuffle BLACK-CARDS))

(define-values (dispatcher to-url)
  (dispatch-rules
   [("czar") czar]))

(define (czar req)
  (let ([black-card (first black-deck)])
    (czar-choose black-card (submitted-white-cards black-card 3))))

(define (czar-choose black-card white-cards)
  (winner black-card 
          (send/suspend/dispatch
           (lambda (embed/url)
             (response/xexpr
              `(html
                (head (title "Continuations Against Humanity")
                      (link ([href "cards.css"] [rel "stylesheet"])))
                (body
                 (h1 "Czar, choose the winner")
                 (div ([class "black card"])
                      (span ,black-card))
                 ,@(map (lambda (text)
                          `(div ([class "white card"])
                                (span ,text)
                                (a ([href ,(embed/url (lambda (req) text))]) "pick")))
                        white-cards))))))))

(define (winner black-card chosen-card)
  (response/xexpr
   `(html
     (head (title "Continuations Against Humanity")
           (link ([href "cards.css"] [rel "stylesheet"])))
     (body
      (h1 "The winner is")
      (div ([class "black card"])
           (span ,black-card))
      (div ([class "white card"])
           (span ,chosen-card))))))

(define (submitted-white-cards black-card n)
  (if (= n 0)
      '()
      (cons (send/suspend/dispatch
             (lambda (embed/url)
               (response/xexpr
                `(html
                  (head (title "Continuations Against Humanity")
                        (link ([href "cards.css"] [rel "stylesheet"])))
                  (body
                   (h1 "Pick a card")
                   (div ([class "black card"])
                        (span ,black-card))
                   ,@(map (lambda (text)
                            `(div ([class "white card"])
                                  (span ,text)
                                  (a ([href ,(embed/url (lambda (req) text))]) "pick")))
                          (take (shuffle WHITE-CARDS) 10)))))))
            (submitted-white-cards black-card (- n 1)))))

(serve/servlet dispatcher
               #:servlet-path "/"
               #:extra-files-paths SERVER-PATHS
               #:servlet-regexp #rx""
               #:listen-ip "0.0.0.0")