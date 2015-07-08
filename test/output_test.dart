import "dart:io";
import "dart:async";
import "dart:convert";

import "package:test/test.dart";

import "package:calzone/transformers.dart";
import "package:calzone/builder.dart";

Map<String, dynamic> nodeJson = {};

main() async {
  await setup();

  test("CollectionsTransformer", () {
    expect(nodeJson["transformers.collections"], equals(true));
  });

  test("PromiseTransformer", () {
    expect(nodeJson["transformers.promise"], equals(true));
  });

  test("ClosureTransformer", () {
    expect(nodeJson["transformers.closure"], equals(true));
  });

  test("BufferTransformer", () {
    expect(nodeJson["transformers.buffer"], equals(true));
  });

  test("BaseTransformer", () {
    expect(nodeJson["transformers.base"], equals(true));
  });

  test("Inheritance", () {
    expect(nodeJson["inheritance"], equals(true));
  });
}

Future setup() async {
  var builder = new Builder("test/lib/test.a.dart", ["calzone.test.a", "calzone.test.b"],
      typeTransformers: [
        new PromiseTransformer(true),
        new ClosureTransformer(),
        new BufferTransformer(),
        // important that collections transformer is last
        new CollectionsTransformer(true)
      ],
      directory: "test/temp",
      isMinified: false);

  var file = new File("test/temp/index.js");
  file.writeAsStringSync(await builder.build());

  var stdout = Process.runSync("node", ["test/output_test.js"]).stdout;
  nodeJson = JSON.decode(stdout);
}
