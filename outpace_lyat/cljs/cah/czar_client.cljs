(ns cah.czar-client
  (:require [cah.common :as c]
            [cljs.core.async :as async]
            [reagent.core :as r])
  (:require-macros [cljs.core.async.macros :refer [go go-loop]]))

(def winner (r/atom false))
(def black-card (r/atom nil))
(def submitted (r/atom 0))
(def white-cards (r/atom []))

(defn received-black-card [text]
  (reset! black-card ["black card" text]))

(defn white-card-submitted []
  (swap! submitted inc))

(defn received-white-card [text]
  (swap! white-cards conj ["white card" text]))

(defn game-over [choice]
  (reset! winner choice))

(defn czar [choice-ch]
  (if @winner
    [:div
     [:div {:class "black card"}
      [:span (second @black-card)]]
     [:div {:class "white card"}
      [:span @winner]]
     [:h2 "Game Over. Thanks for playing!"]]

    (let [cards (when @black-card
                  (if (>= @submitted 3)
                    (cons @black-card @white-cards)
                    (cons @black-card (repeat @submitted ["white card back"]))))]
      [:div
       (for [[class text] cards]
         (if text
           [:div {:class class :on-click #(async/put! choice-ch text)}
            [:span text]]
           [:div {:class class}
            [:span]]))])))

(defn main []
  (let [choice (async/chan)]
    (r/render [czar choice] (js/document.getElementById "container"))
    (go
      (if-let [[send-ch recv-ch] (<! (c/connect "ws://localhost:9001/"))]
        (do
          (.log js/console "Connected")
          (>! send-ch "join as czar")
          (let [black-card (<! recv-ch)]
            (.log js/console "Black card received" black-card)
            (received-black-card black-card)
            (dotimes [_ 3]
              (<! recv-ch)
              (white-card-submitted))
            (dotimes [_ 3]
              (let [white-card (<! recv-ch)]
                (received-white-card white-card)))
            (let [winner (<! choice)]
              (>! send-ch winner)
              (game-over winner))))
        (.log js/console "Could not connect")))))
