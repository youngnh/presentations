(ns cah.player-client
  (:require [cah.common :as c]
            [cljs.core.async :as async]
            [reagent.core :as r])
  (:require-macros [cljs.core.async.macros :refer [go go-loop]]))

(def black-card (r/atom nil))
(def white-cards (r/atom []))
(def game-over (r/atom false))

(defn received-black-card [text]
  (reset! black-card text))

(defn received-white-card [text]
  (swap! white-cards conj text))

(defn game-ended [chosen message]
  (reset! game-over [chosen message]))

(defn player [choice-ch]
  [:div
   (if (not @game-over)
     (when @black-card
       (cons
        [:div {:class "black card"}
         [:span @black-card]]
        (for [text @white-cards]
          [:div {:class "white card" :on-click #(async/put! choice-ch text)}
           [:span text]])))

     (list [:div {:class "black card"}
            [:span @black-card]]
           [:div {:class "white card"}
            [:span (first @game-over)]]
           [:h2 (second @game-over)]))])

(defn main []
  (let [choice (async/chan)]
    (r/render [player choice] (js/document.getElementById "container"))
    (go
      (if-let [[send-ch recv-ch] (<! (c/connect "ws://localhost:9001/"))]
        (do
          (.log js/console "Connected")
          (>! send-ch "join as player")
          (let [black-card (<! recv-ch)]
            (received-black-card black-card))
          (dotimes [_ 10]
            (let [white-card (<! recv-ch)]
              (received-white-card white-card)))
          (<! recv-ch)
          (let [chosen (<! choice)
                _ (>! send-ch chosen)
                msg (<! recv-ch)]
            (game-ended chosen msg)))))))
