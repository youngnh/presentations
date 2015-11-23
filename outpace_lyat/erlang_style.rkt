#lang racket
(require racket/async-channel
         net/rfc6455
         web-server/servlet
         web-server/servlet-env)

(define SERVER-PATHS (list "/Users/n/src/presentations/outpace_lyat"))
(define WHITE-CARDS (file->lines "white-cards.txt"))
(define BLACK-CARDS (file->lines "black-cards.txt"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define czar-ch (make-async-channel 10))
(define player-ch (make-async-channel 40))

(define (placed-in-game #:queue ch)
  (async-channel-put ch (current-thread))
  (match (thread-receive)
    [(cons 'placed-in-game g) g]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (draw-black-card g)
  (thread-send g (cons 'draw-black-card (current-thread)))
  (match (thread-receive)
    [(cons 'black-card black-card) black-card]))

(define (draw-white-cards g)
  (thread-send g (cons 'draw-white-cards (current-thread)))
  (match (thread-receive)
    [(cons 'white-cards white-cards) white-cards]))

(define (black-card g)
  (match (thread-receive)
    [(cons 'black-card black-card) black-card]))

(define (submit-pick g pick)
  (thread-send g (cons (current-thread) pick)))

(define (submit-loop g submissions callback)
  (match (thread-receive)
    ['all-submitted submissions]
    [(cons _ submission) (begin
                           (callback submission)
                           (submit-loop g (cons submission submissions) callback))]))

(define (receive-loop players f)
  (when (not (empty? players))
    (receive-loop (remove (f players) players) f)))

(define (all-players-submitted)
  (match (thread-receive)
    ['all-submitted (void)]))

(define (czar-picked)
  (match (thread-receive)
    [(cons 'czar-picked winner) winner]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (recv-msg c [msg #f])
  (let ([ws-msg (ws-recv c)])
    (if (and msg (not (equal? ws-msg msg)))
        (recv-msg c msg)
        ws-msg)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (matchmaking-thread)
  (displayln "Matchmaking looking for players")
  (let ([czar (async-channel-get czar-ch)]
        [players (for/list ([i '(1 2 3)])
                   (async-channel-get player-ch))])
    (thread (lambda () (game-thread czar players)))
    (matchmaking-thread)))

(define (game-thread czar players)
  (define black-deck (shuffle BLACK-CARDS))
  (define white-deck (shuffle WHITE-CARDS))
  
  (define black-card #f)
  
  (define (draw-black-card)
    (set! black-card (first black-deck))
    (set! black-deck (rest black-deck)))
  
  (define (draw-white-cards)
    (let-values ([(drawn deck-left) (split-at white-deck 10)])
      (set! white-deck deck-left)
      drawn))

  (displayln "Game started")
  
  ;; notify players that they have joined the game
  (for/list ([p (cons czar players)])
    (thread-send p (cons 'placed-in-game (current-thread))))  
  
  ;; czar draws a black-card, notify other players of it
  (match (thread-receive)
    [(cons 'draw-black-card t) (begin
                                 (draw-black-card)
                                 (for/list ([p (cons t players)])
                                   (thread-send p (cons 'black-card black-card))))])
  
  ;; each player draws white cards
  (receive-loop players
    (lambda (players)
      (match (thread-receive)
        [(cons 'draw-white-cards p) (when (member p players)
                                      (thread-send p (cons 'white-cards (draw-white-cards)))
                                      p)])))
  
  ;; receive a white card from each player
  (receive-loop players
    (lambda (players)
      (match (thread-receive)
        [(and pick (cons p card)) (when (member p players)
                                    (thread-send czar pick)
                                    p)])))
  
  (for/list ([p (cons czar players)])
    (thread-send p 'all-submitted))
  
  ;; receive czar's pick
  (let ([winner (thread-receive)])
    ;; send to all players
    (for/list ([p players])
      (thread-send p (cons 'czar-picked winner))))
  
  (displayln "Game ended"))

(define (czar-thread c)
  (let* ([g (placed-in-game #:queue czar-ch)]
         [black-card (draw-black-card g)]
         [_ (ws-send! c black-card)]
         [submissions (submit-loop g '() (lambda _ (ws-send! c "card submitted")))])
    (map (lambda (submission)
           (ws-send! c submission))
         submissions)
    (thread-send g (recv-msg c))))

(define (player-thread p)
  (let* ([g (placed-in-game #:queue player-ch)]
         [black-card (black-card g)])
    (ws-send! p black-card)
    (map (lambda (card)
           (ws-send! p card))
         (draw-white-cards g))
    (ws-send! p "submit a white card")
    (let ([pick (recv-msg p)])
      (submit-pick g pick)
      (all-players-submitted)
      (let ([winner (czar-picked)])
        (if (equal? pick winner)
            (ws-send! p "You've won!")
            (ws-send! p "You lost :/"))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

(define (websocket-handler c state)
  (let ([msg (ws-recv c)])
    (cond
      [(equal? "join as czar" msg) (czar-thread c)]
      [(equal? "join as player" msg) (player-thread c)]
      [else (ws-send! c "invalid message")])
    (ws-close! c)))
              
(thread matchmaking-thread)

(define stop-ws-server
  (ws-serve #:port 9001 websocket-handler))

(serve/servlet dispatcher
               #:servlet-path "/"
               #:servlet-regexp #rx""
               #:extra-files-paths SERVER-PATHS
               #:listen-ip "0.0.0.0")