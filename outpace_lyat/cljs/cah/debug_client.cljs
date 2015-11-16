(ns cah.debug-client
  (:require [cljs.core.async :as async]
            [reagent.core :as r])
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
                          (async/put! recv-ch (.-data event))))
      (aset "onerror" (fn [event]
                        (.error js/console event)))
      (aset "onclose" (fn []
                        (async/close! send-ch)
                        (async/close! recv-ch)
                        (async/close! result-ch))))
    result-ch))

(def send-queue (async/chan 50))

(defn send-message [msg]
  (async/put! send-queue msg))

(defn client []
  (let [msg (r/atom "")]
    (fn []
      [:div
       [:input {:type "text" :size 40 :value @msg :on-change #(reset! msg (.-value (.-target %)))}]
       [:button {:on-click #(send-message @msg)} "Send Message"]])))

(defn main []
  (r/render [client] (js/document.getElementById "container"))
  (go
    (if-let [[send-ch recv-ch] (<! (connect "ws://localhost:9001/"))]
      (do
        (.log js/console "Connected")
        (async/pipe send-queue send-ch)
        (go-loop []
          (when-let [msg (<! recv-ch)]
            (.log js/console "Received" msg)
            (recur))))
      (.log js/console "Could not connect"))))

(main)

