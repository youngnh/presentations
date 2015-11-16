#lang racket
(require racket/control
         net/rfc6455
         web-server/servlet
         web-server/servlet-env)

(struct game (czar-join player-join player-submit) #:mutable)

(define (make-game)
  (game
   (lambda (c) (ws-send! c "game not started yet"))
   (lambda (c) (ws-send! c "czar not yet joined"))
   (lambda (c msg) (ws-send! c "cannot submit yet"))))

(define SERVER-PATHS (list "/Users/n/src/presentations/outpace_lyat"))
(define WHITE-CARDS (file->lines "white-cards.txt"))
(define BLACK-CARDS (file->lines "black-cards.txt"))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (play-game g)
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
  
  (let* ([czar (czar-join g)]
         [black-card (draw-black-card)]
         [_ (ws-send! czar black-card)]
         [players (n-players-join g 3
                    (lambda (p)
                      (ws-send! p black-card)
                      (map (lambda (card) (ws-send! p card)) (draw-white-cards))))]
         [_ (map (lambda (p) (ws-send! p "submit a white card")) players)]
         [submissions (all-players-submit g players
                        (lambda _
                          (ws-send! czar "card submitted")))]
         [_ (map (lambda (submission) (ws-send! czar (cdr submission))) submissions)]
         [winner (czar-pick g czar)])
    (displayln (string-append "Czar chose: " winner))
    (map (lambda (submission)
           (if (equal? (cdr submission) winner)
               (ws-send! (car submission) "You've won!")
               (ws-send! (car submission) "You lost :/")))
         submissions)
    (displayln "Game Over!")))

(define (czar-join g)
  (shift k
    (set-game-czar-join! g
      (lambda (c)
        (thread (lambda () (k c)))
        (set-game-czar-join! g
          (lambda (c)
            (ws-send! c "czar already joined")))))
    (void)))

(define (player-join g)
  (shift k
    (set-game-player-join! g
      (lambda (c)
        (thread (lambda () (k c)))))
    (void)))

(define (player-submit g)
  (shift k
    (set-game-player-submit! g
      (lambda (c msg)
        (thread (lambda () (k (cons c msg))))))
    (void)))

(define (czar-pick g czar)
  (let* ([submission (player-submit g)]
         [p (car submission)])
    (if (equal? p czar)
        (begin
         (set-game-player-submit! g
           (lambda (c msg)
             (ws-send! c "czar pick already submitted")))
         (cdr submission))
        (begin
          (ws-send! p "not the czar")
          (czar-pick g czar)))))

(define (n-players-join g n callback)
  (if (= n 0)
      (begin
        (set-game-player-join! g
          (lambda (c)
            (ws-send! c "game is full")))
        '())
      (let ([player (player-join g)])
        (callback player)
        (cons player (n-players-join g (- n 1) callback)))))

(define (all-players-submit g players callback)
  (if (empty? players)
      (begin
        (set-game-player-submit! g
          (lambda (c msg)
            (ws-send! c "all players have already submitted")))
        '())
      (let* ([submission (player-submit g)]
             [p (car submission)])
        (if (member p players)
            (begin
              (callback submission)
              (cons submission (all-players-submit g (remove p players) callback)))
            (begin
              (ws-send! p "shouldn't have submitted")
              (all-players-submit g players callback))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-values (dispatcher to-url)
  (dispatch-rules
   [("czar") (client-page "czar" "js/czar_client.js")]
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

(define (message-loop g c)
  (let ([msg (ws-recv c)])
    (cond
      [(equal? "join as czar" msg) ((game-czar-join g) c)]
      [(equal? "join as player" msg) ((game-player-join g) c)]
      [else ((game-player-submit g) c msg)])
    (message-loop g c)))

(define the-game (make-game))
(thread (lambda () (reset (play-game the-game))))

(define stop-ws-server
  (ws-serve #:port 9001 (lambda (c state) (message-loop the-game c))))

(serve/servlet dispatcher
               #:servlet-path "/"
               #:servlet-regexp #rx""
               #:extra-files-paths SERVER-PATHS
               #:listen-ip "0.0.0.0")