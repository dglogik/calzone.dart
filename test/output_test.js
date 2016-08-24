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
    a: [1, {
        'c': 3,
        'd': 4
      }],
    b: 2
  };

  var test = new T.CollectionsTest(list, map);

  assert(test.verifyList());
  assert(test.verifyMap());

  // ES6 Map
  map = new Map();

  var submap = new Map();
  submap.set('c', 3);
  submap.set('d', 4);

  map.set('a', [1, submap]);
  map.set('b', 2);

  test = new T.CollectionsTest(list, map);

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
    return 'Hello World!';
  }, function(str) {
    return str;
  });

  assert(test.exec() === 'Hello World!', 'ClosureTest.exec()');
  assert(test.execTwo() === 'Hello World!', 'ClosureTest.execTwo()');
});

describe('transformers.buffer', function() {
  var buffer = new Buffer([1,2,3]);
  var test = new T.BufferTest(buffer);

  var newBuffer = test.getData();
  assert(newBuffer instanceof Buffer);
  assert(newBuffer.length === 3);
  assert(newBuffer[0] === 1);
  assert(newBuffer[1] === 2);
  assert(newBuffer[2] === 3);
});

describe('transformers.base', function() {
  var test = new T.ClassWrapperTest(new T.ClassTest());

  assert(test.invoke() === 'Hello World!');
  assert(test.c.invoke() === 'Hello World!');
});

describe('inheritance', function() {
  var _super = T.ClassTest;

  function InheritanceTest() {
    _super.call(this);
  }

  InheritanceTest.prototype = Object.create(_super.prototype);

  InheritanceTest.prototype.invoke = function() {
    return 'Salutations, human.';
  };

  var test = new T.ClassWrapperTest(new InheritanceTest());

  assert(_super.prototype.invoke.call(test.c) === "Hello World!");
  assert(test.invoke() === 'Salutations, human.');
  assert(test.c.invoke() === 'Salutations, human.');

  InheritanceTest.prototype.invoke = function() {
    return this.str;
  };

  assert(test.invoke() === 'Hello World!');
  assert(test.c.invoke() === 'Hello World!');
});

describe('default_values', function() {
  var test = new T.B();

  assert(test.d() === 'Hello World!false2.55');

  assert(T.getOne() === 1);
});

describe('retain_wrapper_instance', function() {
  var classTest = new T.ClassTest();
  classTest.abc = 'xyz';

  var test = new T.ClassWrapperTest(classTest);

  assert(test.c.abc === 'xyz');

  test = new T.ClassWrapperTest.nothing();

  assert(test.c.invoke() === 'Hello World!');
});
console.log(JSON.stringify(json));
