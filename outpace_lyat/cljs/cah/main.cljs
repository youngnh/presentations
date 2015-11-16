(ns cah.main
  (:require [cah.czar-client]
            [cah.player-client]
            [cah.debug-client]))

(def ^:export czar cah.czar-client/main)
(def ^:export player cah.player-client/main)
(def ^:export debug cah.debug-client/main)

