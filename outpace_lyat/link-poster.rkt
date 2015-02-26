#lang racket
(require "config.rkt"
         json
         net/http-client
         net/uri-codec
         web-server/servlet
         web-server/servlet-env)

(define-values (dispatcher to-url)
  (dispatch-rules
   [("slack" "link") share-link]))

(define (share-link req)
  (define slack-token (get-slack-token))
  (define api-response
    (call-with-values
     (lambda ()
       (slack-api "chat.postMessage"
                  `((token . ,slack-token)
                    (channel . "#webhook_tests")
                    (text . "http://docs.racket-lang.org/reference/cont.html"))))
     response->string))
  (response/xexpr
   `(html (head (title "chat.postMessage response"))
          (body
           (pre ,api-response)))))

(define (get-slack-token)
  (define orig-redirect (box #f))
  (define rand (random 100000000))
  (define req (prompt-authorize orig-redirect (number->string rand)))
  
  (check-state rand (num-param req #"state"))
  (obtain-slack-access-token (string-param req #"code") (unbox orig-redirect)))

(define (prompt-authorize redirect-to state)
  (send/suspend 
   (lambda (k-url)
     (set-box! redirect-to (string-append DOMAIN k-url))
     (response/xexpr
      `(html (body (p "Please authorize this app to post a link on your behalf: "
                      (a ([href ,(url->string (slack-oauth-uri (unbox redirect-to) state))]) "https://slack.com/oauth/authorize"))))))))

(define (obtain-slack-access-token code orig-redirect)
  (define-values (status-line headers port)
    (slack-api "oauth.access"
               `((client_id . ,SLACK-CLIENT-ID)
                 (client_secret . ,SLACK-CLIENT-SECRET)
                 (code . ,code)
                 (redirect_uri . ,orig-redirect))))
  (define resp (read-json port))  
  (hash-ref resp 'access_token))

(define (slack-api api-method params)
  (http-sendrecv "slack.com" (string-append "/api/" api-method)
                 #:ssl? #t
                 #:method "POST"
                 #:headers (list "Content-Type: application/x-www-form-urlencoded")
                 #:data (alist->form-urlencoded params)))

(define (response->string status-line headers port)
  (let ([out (open-output-string)])
    (displayln status-line out)
    (for ([header headers])
      (displayln header out))
    (newline out)
    (for ([line (in-lines port)])
      (displayln line out))
    (get-output-string out)))

(define (slack-oauth-uri redirect-to state)
  (struct-copy url (string->url "https://slack.com/oauth/authorize")
               [query `((client_id . ,SLACK-CLIENT-ID)
                        (redirect_uri . ,redirect-to)
                        (scope . "identify,read,post")
                        (state . ,state)
                        (team . ,OUTPACE-TEAM-ID))]))

(define (num-param req id)
  (match (bindings-assq id (request-bindings/raw req))
    [(? binding:form? b)
     (string->number (bytes->string/utf-8 (binding:form-value b)))]))

(define (string-param req id)
  (match (bindings-assq id (request-bindings/raw req))
    [(? binding:form? b)
     (bytes->string/utf-8 (binding:form-value b))]))

(define-struct (exn:mismatched-salt exn) ())

(define (check-state provided returned)
  (unless (eq? provided returned)
    (raise (make-exn:mismatched-salt))))

(serve/servlet dispatcher
               #:servlet-path "/"
               #:servlet-regexp #rx""
               #:listen-ip "0.0.0.0")