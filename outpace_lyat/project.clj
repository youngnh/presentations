(defproject cah-client "0.0.1"
  :dependencies [[org.clojure/clojure "1.7.0"]
                 [org.clojure/clojurescript "1.7.107"]
                 [org.clojure/core.async "0.2.374"]
                 [reagent "0.5.1"]]

  :plugins [[lein-cljsbuild "1.0.6"]]

  :hooks [leiningen.cljsbuild]

  :cljsbuild {:builds {:debug
                       {:source-paths ["cljs"]
                        :compiler {:output-dir "compiled/cljsbuild/debug/"
                                   :output-to "js/debug_client.js"
                                   :optimizations :simple}}
                       :czar
                       {:source-paths ["cljs"]
                        :compiler {:output-dir "compiled/cljsbuild/czar"
                                   :output-to "js/czar_client.js"
                                   :optimizations :simple}}

                       :player
                       {:source-paths ["cljs"]
                        :compiler {:output-dir "compiled/cljsbuild/player"
                                   :output-to "js/player_client.js"
                                   :optimizations :simple}}}})
