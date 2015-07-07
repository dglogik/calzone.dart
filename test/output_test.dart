import "dart:io";
import "dart:async";
import "dart:convert";

import "package:test/test.dart";

import "package:calzone/compiler.dart";
import "package:calzone/transformers.dart";
import "package:calzone/patcher.dart";

bool dart2js(List flags, String outputFile, String inputFile) {
  var arguments = flags.map((flag) => "--$flag").toList();
  arguments.addAll(["-o", outputFile, inputFile]);
  return Process.runSync("dart2js", arguments).exitCode == 0;
}

Compiler compiler = new Compiler("test/lib/test.a.dart", "test/temp/index.js.info.json", "test/temp/index.scraper.json", typeTransformers: [
  new PromiseTransformer(true),
  new ClosureTransformer(),
  new BufferTransformer(),
  // important that collections transformer is last
  new CollectionsTransformer(true)
]);

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
  var temp = new Directory("test/temp");

  if(temp.existsSync())
    temp.deleteSync(recursive: true);
  temp.createSync();

  await dart2js(["dump-info",
          "trust-primitives",
          "enable-experimental-mirrors"],
      "test/temp/index.js",
      "test/lib/test.a.dart");

  var scraper = new Scraper("test/temp/index.js", "test/temp/index.js.info.json");

  var scraperFile = new File("test/temp/index.scraper.json");

  scraperFile.createSync();
  scraperFile.writeAsStringSync(await scraper.scrape());

  var str = compiler.compile(["calzone.test.a", "calzone.test.b"]);

  var patcher = new Patcher("test/temp/index.js", "test/temp/index.js.info.json",
    str.toString().split('\n'), target: PatcherTarget.NODE);

  var patcherOutput = patcher.patch();

  var file = new File("test/temp/index.js");
  file.writeAsStringSync(patcherOutput);

  var stdout = Process.runSync("node", ["test/output_test.js"]).stdout;
  nodeJson = JSON.decode(stdout);
}
