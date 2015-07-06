library calzone.test.a;

import "test.b.dart";

part "test.a.part.dart";

class A extends B {
  static final String stat = "Hello World!";
  static final String _stat = "Hello World!";
}

class B extends C {
  c() {
  }

  d(String hello, hello2, {String hi, String string: "Hello World!", bool boolean: false, num number: 2.55}) {
  }

  e([Map map = const {"1": 1, "2": 2, "3": 3}, List list = const [1, 2, 3]]) {
  }
}
