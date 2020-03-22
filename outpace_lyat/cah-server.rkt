#lang racket
(require racket/control
         net/rfc6455
         web-server/servlet
         web-server/servlet-env)

(define current-continuation #f)

(define (set!/cc)
  (shift k (set! current-continuation k)))

(define (czar-join)
  (let-values ([(c msg) (set!/cc)])
    (if (equal? msg "join as czar")
      c
      (czar-join))))

(define (player-join)
  (let-values ([(c msg) (set!/cc)])
    (if (equal? msg "join as player")
      c
      (player-join))))

(struct submission (card player))

(define (player-submit)
  (let-values ([(c msg) (set!/cc)])
    (submission msg c)))

(define N-PLAYERS 3)
(define BLACK-CARDS (file->lines "black-cards.txt"))
(define WHITE-CARDS (file->lines "white-cards.txt"))

(define (play-game)
  (define black-deck (shuffle BLACK-CARDS))
  (define white-deck (shuffle WHITE-CARDS))

  (define (draw-black-card)
    (begin0
      (first black-deck)
      (set! black-deck (rest black-deck))))

  (define (draw-white-cards)
    (let-values ([(drawn deck-left) (split-at white-deck 10)])
      (set! white-deck deck-left)
      drawn))

  (define czar (czar-join))
  (define black-card (draw-black-card))
  (ws-send! czar black-card)

  (define (all-players-join)
    (define (go n players)
      (if (= n 0)
          players
          (let ([player (player-join)])
            (ws-send! player black-card)
            (map (lambda (card) (ws-send! player card)) (draw-white-cards))
            (go (- n 1) (cons player players)))))
      (go N-PLAYERS null))

  (define players (all-players-join))

  (map (lambda (p) (ws-send! p "submit a white card")) players)

  (define (all-players-submit)
    (define (go ps submissions)
      (if (set-empty? ps)
          submissions
          (let* ([s (player-submit)]
                 [player (submission-player s)])
            (if (set-member? ps player)
                (begin
                  (ws-send! czar "card submitted")
                  (go (set-remove ps player) (cons s submissions)))
                (begin
                 (ws-send! player "already submitted")
                 (go ps submissions))))))
    (go players null))

  (define submissions (all-players-submit))

  (map (lambda (s) (ws-send! czar (submission-card s))) submissions)

  (define (czar-pick-winner)
    (let* ([s (player-submit)]
           [player (submission-player s)])
      (if (equal? player czar)
          (submission-card s)
          (begin
            (ws-send! player "not the czar")
            (czar-pick-winner)))))

  (define winner (czar-pick-winner))
  (displayln (format "Czar chose: ~s" winner))

  (map (lambda (s)
         (if (equal? (submission-card s) winner)
             (ws-send! (submission-player s) "You've won!")
             (ws-send! (submission-player s) "You lost :/")))
       submissions)

  (displayln "Game Over, quitting"))

;;;;;;;;;; Server

(define SERVER-PATHS (list "/Users/n/src/presentations/outpace_lyat"))

(define-values (dispatcher to-url)
  (dispatch-rules
   [("czar") (client-page "czar" "js/czar_client.js")]
   [("player") (client-page "player" "js/player_client.js")]
   [("debug") (client-page "debug" "js/debug_client.js")]))

(define ((client-page module script) req)
  (response/xexpr
   `(html
     (head (title "Continuations Against Humanity")
           (link ([href "css/cards.css"] [rel "stylesheet"])))
     (body
      (h1 ,module)
      (div ([id "container"]))
      (script ([src ,script]))
      (script ,(format "cah.main.~a()" module))))))

(define (message-loop c)
  (let ([msg (ws-recv c)])
    (if current-continuation
      (current-continuation c msg)
      (ws-send! c "error"))
    (message-loop c)))

(thread (lambda () (reset (play-game))))

(define stop-ws-server
  (ws-serve #:port 9001 (lambda (c request) (message-loop c))))

(serve/servlet dispatcher
               #:servlet-path "/"
               #:servlet-regexp #rx""
               #:extra-files-paths SERVER-PATHS
               #:listen-ip "0.0.0.0")
