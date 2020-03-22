(ns cah.common
  (:require [cljs.core.async :as async])
  (:require-macros [cljs.core.async.macros :refer [go go-loop]]))

(defn connect [uri]
  (let [send-ch (async/chan 10)
        recv-ch (async/chan 100)
        result-ch (async/chan)
        websocket (js/WebSocket. uri)]
    (doto websocket
      (aset "onopen" (fn []
                       (go-loop []
                         (when-let [msg (<! send-ch)]
                           (.log js/console "Sending" msg)
                           (.send websocket msg)
                           (recur)))
                       (async/put! result-ch [send-ch recv-ch])
                       (async/close! result-ch)))
      (aset "onmessage" (fn [event]
                          (let [msg (.-data event)]
                            (.log js/console "Received" msg)
                            (async/put! recv-ch msg))))
      (aset "onerror" (fn [event]
                        (.error js/console event)))
      (aset "onclose" (fn []
                        (async/close! send-ch)
                        (async/close! recv-ch)
                        (async/close! result-ch))))
    result-ch))
