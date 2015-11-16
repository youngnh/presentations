(ns cah.debug-client
  (:require [cah.common :as c]
            [cljs.core.async :as async]
            [reagent.core :as r])
  (:require-macros [cljs.core.async.macros :refer [go go-loop]]))


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
    (if-let [[send-ch recv-ch] (<! (c/connect "ws://localhost:9001/"))]
      (do
        (.log js/console "Connected")
        (async/pipe send-queue send-ch)
        (go-loop []
          (when-let [msg (<! recv-ch)]
            (.log js/console "Received" msg)
            (recur))))
      (.log js/console "Could not connect"))))
