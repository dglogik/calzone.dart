var T = require('./temp');
var json = {};

function assert(bool, desc) {
  if(!bool)
    throw new Error('assert failed: ' + (desc || ''));
}

function describe(id, cb) {
  try {
    cb();
    json[id] = true;
  } catch(e) {
    json[id] = e.stack.toString();
  }
}

describe('transformers.collections', function() {
  var list = ['a', 'b', {'a': 1, 'b': 2}];
  var map = {
    'a': [1, {
        'c': 3,
        'd': 4
      }],
    'b': 2
  };

  var test = new T.CollectionsTest(list, map);

  assert(test.verifyList());
  assert(test.verifyMap());

  list = test.getList();
  map = test.getMap();

  assert(list[0] === 'a'
      && list[1] === 'b'
      && list[2].constructor.name === 'Object'
      && list[2].a === 1
      && list[2].b === 2);

  assert(map.a
      && Array.isArray(map.a)
      && map.a[0] === 1
      && map.a[1].constructor.name === 'Object'
      && map.a[1].c === 3
      && map.a[1].d === 4
      && map.b == 2);
});

describe('transformers.promise', function() {
  var test = new T.PromiseTest(new Promise(function(resolve) {
    resolve();
  }));

  assert(test.getFuture().then, 'PromiseTest.getFuture() #1');

  test = new T.PromiseTest({
    then: function() {
      return {
        catch: function() {}
      }
    },
    catch: function() {
    }
  });

  assert(test.getFuture().then, 'PromiseTest.getFuture() #2');
});

describe('transformers.closure', function() {
  var test = new T.ClosureTest(function() {
    return "Hello World!";
  });

  assert(test.exec() === "Hello World!", 'ClosureTest.exec()');
});

console.log(JSON.stringify(json));
