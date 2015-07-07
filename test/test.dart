import "package:test/test.dart";
import "package:analyzer/analyzer.dart" show ParameterKind;

import "package:calzone/analysis.dart";
import "package:calzone/compiler.dart";

Compiler compiler = new Compiler.empty("test/lib/test.a.dart");
Analyzer analyzer = compiler.analyzer;

main() {
  test("Analyzer#getClass()", () {
    expect(analyzer.getClass("calzone.test.a", "A"), isNotNull);
    expect(analyzer.getClass("calzone.test.a", "B"), isNotNull);
    expect(analyzer.getClass("calzone.test.a", "C"), isNotNull);
    expect(analyzer.getClass("calzone.test.b", "D"), isNotNull);
  });

  test("Analyzer#getFunctionParameters()", () {
    expect(analyzer.getFunctionParameters("calzone.test.a", "c", "B").length, equals(0));
    expect(analyzer.getFunctionParameters("calzone.test.a", "d", "B").length, equals(6));
    expect(analyzer.getFunctionParameters("calzone.test.a", "e", "B").length, equals(2));
  });

  test("Class.name", () {
    expect(analyzer.getClass("calzone.test.a", "A").name, equals("A"));
    expect(analyzer.getClass("calzone.test.a", "B").name, equals("B"));
    expect(analyzer.getClass("calzone.test.a", "C").name, equals("C"));
    expect(analyzer.getClass("calzone.test.b", "D").name, equals("D"));
  });

  test("Class.libraryName", () {
    expect(analyzer.getClass("calzone.test.a", "A").libraryName, equals("calzone.test.a"));
    expect(analyzer.getClass("calzone.test.a", "B").libraryName, equals("calzone.test.a"));
    expect(analyzer.getClass("calzone.test.a", "C").libraryName, equals("calzone.test.a"));
    expect(analyzer.getClass("calzone.test.b", "D").libraryName, equals("calzone.test.b"));
  });

  test("Class.inheritedFrom", () {
    expect(analyzer.getClass("calzone.test.b", "D").inheritedFrom, equals([]));
    expect(analyzer.getClass("calzone.test.a", "C").inheritedFrom, equals(["D"]));
    expect(analyzer.getClass("calzone.test.a", "B").inheritedFrom, equals(["C", "D"]));
    expect(analyzer.getClass("calzone.test.a", "A").inheritedFrom, equals(["B", "C", "D"]));
  });

  test("Class.getters", () {
    expect(analyzer.getClass("calzone.test.a", "B").getters, equals([]));
    expect(analyzer.getClass("calzone.test.a", "C").getters, equals(["a"]));
  });

  test("Class.setters", () {
    expect(analyzer.getClass("calzone.test.a", "B").setters, equals([]));
    expect(analyzer.getClass("calzone.test.a", "C").setters, equals(["a"]));
  });

  test("Class.staticFields", () {
    expect(analyzer.getClass("calzone.test.a", "A").staticFields, equals(["stat", "_stat"]));
  });

  test("Class.functions", () {
    expect(analyzer.getClass("calzone.test.a", "A").functions.length, equals(0));
    expect(analyzer.getClass("calzone.test.a", "C").functions.keys, equals(["b"]));
    expect(analyzer.getClass("calzone.test.b", "D").functions.keys, equals(["b"]));
  });

  test("Parameter.type", () {
    // (String hello, hello2, {String hi, String string: "Hello World!", bool boolean: false, num number: 2.55})

    var types = analyzer.getFunctionParameters("calzone.test.a", "d", "B").map((param) => param.type).toList();

    expect(types[0], equals("String"));
    expect(types[1], equals("dynamic"));
    expect(types[2], equals("String"));
    expect(types[3], equals("String"));
    expect(types[4], equals("bool"));
    expect(types[5], equals("num"));
  });

  test("Parameter.name", () {
    // (String hello, hello2, {String hi, String string: "Hello World!", bool boolean: false, num number: 2.55})

    var types = analyzer.getFunctionParameters("calzone.test.a", "d", "B").map((param) => param.name).toList();

    expect(types[0], equals("hello"));
    expect(types[1], equals("hello2"));
    expect(types[2], equals("hi"));
    expect(types[3], equals("string"));
    expect(types[4], equals("boolean"));
    expect(types[5], equals("number"));

    // ([Map map = const {"1": 1, "2": 2, "3": 3}, List list = const [1, 2, 3]])

    types = analyzer.getFunctionParameters("calzone.test.a", "e", "B").map((param) => param.name).toList();

    expect(types[0], equals("map"));
    expect(types[1], equals("list"));
  });

  test("Parameter.defaultValue", () {
    // (String hello, hello2, {String hi, String string: "Hello World!", bool boolean: false, num number: 2.55})

    var types = analyzer.getFunctionParameters("calzone.test.a", "d", "B").map((param) => param.defaultValue).toList();

    expect(types[2], equals("null"));
    expect(types[3], equals('"Hello World!"'));
    expect(types[4], equals("false"));
    expect(types[5], equals("2.55"));

    // ([Map map = const {"1": 1, "2": 2, "3": 3}, List list = const [1, 2, 3]])

    types = analyzer.getFunctionParameters("calzone.test.a", "e", "B").map((param) => param.defaultValue).toList();

    expect(types[0], equals('{"1":1,"2":2,"3":3}'));
    expect(types[1], equals("[1,2,3]"));
  });

  test("Parameter.kind", () {
    // (String hello, hello2, {String hi, String string: "Hello World!", bool boolean: false, num number: 2.55})

    var types = analyzer.getFunctionParameters("calzone.test.a", "d", "B").map((param) => param.kind).toList();

    expect(types[0], equals(ParameterKind.REQUIRED));
    expect(types[1], equals(ParameterKind.REQUIRED));
    expect(types[2], equals(ParameterKind.NAMED));
    expect(types[3], equals(ParameterKind.NAMED));
    expect(types[4], equals(ParameterKind.NAMED));
    expect(types[5], equals(ParameterKind.NAMED));

    // ([Map map = const {"1": 1, "2": 2, "3": 3}, List list = const [1, 2, 3]])

    types = analyzer.getFunctionParameters("calzone.test.a", "e", "B").map((param) => param.kind).toList();

    expect(types[0], equals(ParameterKind.POSITIONAL));
    expect(types[1], equals(ParameterKind.POSITIONAL));
  });

  group("Compiler", () {
    // TODO: Compiler

    // TODO: Base Transformer

    // TODO: Class

    // TODO: Function
  });

  group("Patcher", () {
    // TODO: Patcher

    // TODO: Scraper
  });
}
