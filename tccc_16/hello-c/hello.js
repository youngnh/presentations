goog.provide('example');

goog.require('goog.dom');

example.sayHello = function(message) {
    goog.dom.getElement('hello').innerHTML = 'Hello ' + message;
};

example.sayHello('TCCC 16!');
