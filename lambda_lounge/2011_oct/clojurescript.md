% ClojureScript
% Nate Young
% October 6, 2011

# What is this?

- Clojure + JavaScript

> - minus Java
> - = ClojureScript
> - Clever!

# Clojure Refresher

- Lisp
- Just a bit more syntax

> - _(Ask Mark Volkmann)_

# Clojure Refresher

- Clojure syntax

~~~~{.clojure}
(defn whatsit [bacon eggs]
  (let [x (some-calculation)]
    (do-a-thing (cook bacon eggs) x [1 2 3])))
~~~~

- Common Lisp syntax

~~~~
(defun whatsit (bacon eggs)
  (let ((x (some-calculation)))
    (do-a-thing (cook bacon eggs) x '(1 2 3))))
~~~~

# Clojure Refresher

- Rich collections
- Maps, Sets, Vectors

~~~~{.clojure}
{"dog" "cat",
 "hawk" "squirrel",
 "emacs" "vim"}
~~~~
 
~~~~{.clojure}
#{"dog" "hawk" "emacs"}
~~~~

~~~~{.clojure}
["cat", "squirrel" "vim"]
~~~~

# Clojure Refresher

- Immutable data structures
- Structural sharing

~~~~{.clojure}
(def x {"dog" "cat"
        "hawk" "squirrel"
        "emacs" "vim"})

(assoc x "death star" "alderaan")
~~~~

> - _(Ask Mark Volkmann)_

# Clojure Refresher

- atoms _(uncoordinated. cowboys)_

~~~~{.clojure}
(def wyatt (atom 5))

(reset! wyatt 500)
(swap! wyatt (fn [old] (* 100 old)))

(deref wyatt)
~~~~

- refs _(coordinated, transaction-oriented. swiss bankers)_

~~~~{.clojure}
(def johann (ref 5))

(ref-set johann 500)
(alter johann (fn [old] (* 100 old)))
(commute johann (fn [old] (* 100 old)))

@johann
~~~~

- promises, futures

~~~~{.clojure}
(future (launch-the-missiles))

(let [launch-the-missiles (promise)]
  (when (le-tired?)
    (future (take-a-nap) (deliver launch-the-missiles :ok)))
  @launch-the-missiles)
~~~~

# Clojure Refresher

- Clojure is a compiled language
- **.clj** -> in-memory bytecode
-- open a repl, `(require lib)`
- **.clj** -> on-disk bytecode (.class)
-- open a repl, `(compile lib)`

# ClojureScript

- getting it

~~~~{.bash}
git clone git://github.com/clojure/clojurescript.git
~~~~

- starting it

~~~~{.bash}
./script/bootstrap
./script/repljs
~~~~

# What's Inside

- Clojure, Closure, and ClojureScript
- Hereafter known as:
    - Clojure or clj
    - GClosure
    - ClojureScript or cljs
- _src/clj_
- _src/cljs_

# What's Inside

- a REPL
- a compiler

# cljsc

- In ClojureScript _(.cljs)_

~~~~{.clojure}
(defn greet [s]
  (str "Hello " s "!"))
~~~~

- From a Clojure _(clj)_ REPL:

~~~~{.clojure}
(use '[cljs.closure])

(-compile '(defn greet [s]
             (str "Hello " s "!"))
          {})
~~~~

~~~~{.javascript}
cljs.user.greet = (function greet(s){
return cljs.core.str.call(null,"Hello ",s,"!");
});
~~~~

# REPL

- Read _(homoiconic language, returns a List)_
- Eval `(-evaluate lst)`
- Print _(duh)_
- Loop _(recur. no tail recursion)_

# REPL

- Compile from the repl

~~~~{.clojure}
(cljsc/build "src" {:output-dir "stuff"})
~~~~

~~~~{.clojure}
(cljsc/build "stuff.cljs" {:output-to "stuff.js"})
~~~~

~~~~{.clojure}
(cljsc/build "src" {:optimizations :advanced :output-to "stuff.js"})
~~~~

~~~~{.clojure}
(cljsc/build "src" {:optimizations :advanced :libs ["box2d" "not-jQuery"]})
~~~~

# ClojureScript is Clojure

- primitives
- collections
- symbols, keywords
- deftype, protocols
- destructuring
- libs (`clojure.set`, `clojure.string`, `clojure.walk`, `clojure.zip`, `core.logic`, `core.match`)

# ClojureScript is Clojure

- Underway
- full persistence
- defrecord
- multimethods
- testing framework
- fill in clojure.core gaps

# ClojureScript is Not Clojure

- No eval
- macros are written in Clojure
- no threads/threading
- not portable
- no structs, proxy

# ClojureScript is Not Clojure

- In Limbo
- Agents (webworkers?)

# Macros are special

- but Rich loves them

~~~~{.clojure}
(ns lambda.lounge
  (:require-macros [clojure.core :as m]))

(m/->> xs 
       (map f1) 
       (reduce f2))
~~~~

# JS interop

- V8
- Node.js
- external js libraries
- interop constructs
    - **.** and **..**
    - Math/PI
    - `(.field x)`
    - `(obj.field.another x 5 5)`
    - `(. x (method 1 2))`
    - `(js/alert "generic greeting")`

# Do I need to know JS?

- No

> - Yes

# REPL Redux

- Start a browser
- Load plain html with compiled cljs
- REPL sends forms to browser for evaluation
- Script the browser!

# Browser REPL in detail

- Two files:
- **clojure.repl.browser** _(.clj)_
- **clojure.browser.repl** _(.cljs)_

> - not confusing _at all_

# Browser REPL in detail

> - GClosure XPC (Cross Page Channel) lib
> - Child iframe, makes request to clj server
> - clj server gives child iframe the form to evaluate
> - Child iframe gives form to parent page
> - Parent page evaluates, gives child iframe the result
> - Child iframe POSTs the result
> - clj repl prints the result
> - writes response when user has given another form
> - Loop
> - To the Source!

# Clojure on the Server, ClojureScript in the Browser

- parens everywhere

# Lessons learned, pitfalls

- valid compilation, program does nothing

![](/home/n/Pictures/goggles.jpg)

> - **SOLUTION**: use _"dev mode"_ compilation
> - cljsc takes a long time to start up
> - **SOLUTION**: compile from the REPL

# Questions?
