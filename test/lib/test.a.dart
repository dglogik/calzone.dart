library calzone.test.a;

import "dart:async";
import "dart:collection";
import "dart:typed_data";

import "test.b.dart";

part "test.a.part.dart";

class CollectionsStub {
  final LinkedHashMap _map;

  CollectionsStub(this._map);

  List getMap() {
    return [_map.keys, _map.values];
  }
}

class CollectionsTest {
  // same as getList
  final List list;

  // same as getMap
  final Map<String, List> map;

  CollectionsTest(this.list, this.map);

  List getList() {
    return ["a", "b", {"a": 1, "b": 2}];
  }

  Map getMap() {
    return {
      "a": [1, {
          "c": 3,
          "d": 4
        }],
      "b": 2
    };
  }

  bool verifyList() {
    if(list[0] == "a"
        && list[1] == "b"
        && list[2] is Map
        && list[2].containsKey("a")
        && list[2]["a"] == 1
        && list[2].containsKey("b")
        && list[2]["b"] == 2)
      return true;
    return false;
  }

  bool verifyMap() {
    if(map.containsKey("a")
        && map["a"] is List
        && map["a"][0] == 1
        && map["a"][1] is Map
        && map["a"][1].containsKey("c")
        && map["a"][1]["c"] == 3
        && map["a"][1].containsKey("d")
        && map["a"][1]["d"] == 4
        && map.containsKey("b")
        && map["b"] == 2)
      return true;
    return false;
  }
}

class PromiseTest {
  final Future future;

  PromiseTest(this.future);

  Future getFuture() {
    if(!(future is Future))
      throw future.runtimeType;
    return future.then((_) {});
  }
}

class ClosureTest {
  final Function closure;
  final Function closure2;

  ClosureTest(this.closure, this.closure2);

  dynamic exec() {
    return closure();
  }

  dynamic execTwo() {
    return closure2("Hello World!");
  }
}

class ClassTest {
  String get str => "Hello World!";

  ClassTest();

  String invoke() {
    return str;
  }
}

class ClassWrapperTest {
  final ClassTest c;

  ClassWrapperTest(this.c);

  ClassWrapperTest.nothing():
    c = new ClassTest();

  String invoke() =>
    c.invoke();
}

class BufferTest {
  final ByteData data;

  BufferTest(this.data);

  ByteData getData() =>
    new ByteData.view(data.buffer);
}

class ConstructorTest {
  final String hello;

  ConstructorTest.world([this.hello = "world"]);
}

class A extends B {
  static final String stat = "Hello World!";
  static final String _stat = "Hello World!";
}

class B extends C {
  c() {
  }

  String d(String hello, hello2, {String hi, String string: "Hello World!", bool boolean: false, num number: 2.55}) {
    if(string != "Hello World!" || boolean != false || number != 2.55)
      throw new StateError("defaults didn't work");
    return string + boolean.toString() + number.toString();
  }

  e([Map map = const {"1": 1, "2": 2, "3": 3}, List list = const [1, 2, 3]]) {
  }
}
