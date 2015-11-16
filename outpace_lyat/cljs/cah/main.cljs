(ns cah.main
  (:require [cah.czar-client]
            [cah.debug-client]))

(def ^:export czar cah.czar-client/main)
(def ^:export debug cah.debug-client/main)

