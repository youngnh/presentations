// file: fn.js
// author: Nate Young
// date: Feb 5, 2009
//
// This file contains a select few functions that make
// writing Javascript using functional concepts such as
// currying, tail recursion, method chaining and monads
// easier and more efficient to use.

function curry(f) {
    return function() {
        var args = Array.prototype.slice.call(arguments);
        if(args.length == 0)
            return f;
        if(args.length < f.arity) {
            return function(last) {
                var allargs = args.slice();
                allargs.push(last);
                return f.apply(null, allargs);
            };
        }
        return f.apply(null, args);
    };
}

Function.prototype.curry = function() {
    return curry(this);
};

function bounce() {
    var args = Array.prototype.slice.call(arguments);
    return { bounce: true, arguments: args };
}

function ret(r) {
    return { bounce: false, result: r };
}

function trampoline(f) {
    return function() {
        var args = Array.prototype.slice.call(arguments);
        while(true) {
            var result = f.apply(null, args);
            if(result.bounce) {
                args = result.arguments;
            } else {
                return result.result;
            }
        }
    };
}

Function.prototype.trampoline = function() {
    return trampoline(this);
};

function next(f, g) {
    return function(x) {
        return g(f(x));
    };
}

Function.prototype.next = function(g) {
    return next(this, g);
};

// evaluate a cps function
function run(f, x) {
    return f(x, function() {});
}

// cps here stands for "continuation passing style"
// this function "lifts" a regular function to a cps function.
//
// see http://www.cs.umd.edu/projects/PL/arrowlets/
// for better examples written by smarter people
function cps(f) {
    var fn = function(x, k) {
        return f.next(k)(x);
    };
    fn.run = run.curry()(fn);
    fn.next = cpsnext.curry()(fn); // redefine next for cps functions
    return fn;
}

// f and g here should be cps functions
// (take an argument and a continuation)
// cpsnext will return a new cps function
function cpsnext(f, g) {
    var fn = function(x, k) {
        return f(x, function(y) { g(y, k); });
    };
    fn.run = run.curry()(fn);
    fn.next = cpsnext.curry()(fn); // redefine next for cps functions
    return fn;
}

Function.prototype.cps = function() {
    return cps(this);
};

// event handling
function eventH(target, evnt) {
    var f = function(x, k) {
        function handle(event) {
            target.removeEventListener(evnt, handle, false);
            k(event);
        }
        target.addEventListener(evnt, handle, false);
    };
    f.run = run.curry()(f);
    f.next = cpsnext.curry()(f);
    return f;
}

// with the above functions, you can now write things like:
// eventH(h1, 'click').next(sayHey.cps()).next(eventH(h1, 'click')).next(sayHey.cps()).run()
// which will handle two successive clicks

function repeat(x, k) {
    k({ repeat: true, value: x });
}
repeat.run = run.curry()(repeat);
repeat.next = cpsnext.curry()(repeat);

function done(x, k) {
    k({ repeat: false, value: x });
}
done.run = run.curry()(done);
done.next = cpsnext.curry()(done);

// f must be a cps function
function loop(f) {
    function rep(x, k) {
        return f(x, function(y) {
                if(y.repeat) {
                    return rep(y.value, k);
                } else {
                    return k(y.value);
                }
            });
    }
    rep.run = run.curry()(rep);
    rep.next = cpsnext.curry()(rep);
    return rep;
}

Function.prototype.loop = function() {
    return loop(this);
};

// with the loop function you can write things like:
// eventH(h1, 'click').next(sayHey.cps()).next(repeat).loop().run()
// which will re-register the click handler after being clicked