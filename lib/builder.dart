library calzone.builder;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:calzone/compiler.dart";
import "package:calzone/patcher.dart";
import "package:calzone/util.dart";

enum BuilderStage { ALL, COMPILE, WRAP }

bool _dart2js(
    List flags, String outputFile, String inputFile, PatcherTarget target,
    {bool isMinified: false}) {
  var arguments = flags.map((flag) => "--$flag").toList();
  if (isMinified) arguments.add("-m");
  if (target == PatcherTarget.BROWSER) {
    arguments.add("-Dcalzone.browser=true");
  } else {
    arguments.add("-Dcalzone.node=true");
  }

  arguments.addAll(["-Dcalzone.build=true", "-o", outputFile, inputFile]);
  return Process.runSync("dart2js", arguments).exitCode == 0;
}

class Builder {
  final BuilderStage stage;
  final PatcherTarget target;

  final List<String> include;
  final List<TypeTransformer> typeTransformers;
  final List<CompilerVisitor> compilerVisitors;

  final String dartFile;
  final String directory;

  final bool isMinified;

  Builder(this.dartFile, include,
      {this.stage: BuilderStage.ALL,
      this.target: PatcherTarget.NODE,
      this.typeTransformers: const [],
      this.compilerVisitors: const [],
      this.directory: "temp",
      this.isMinified: true})
      : this.include = include is List<String>
            ? include
            : new File(include).readAsLinesSync().where((line) =>
                line.trim().length > 0 && !line.trim().startsWith("#"));

  Future<String> build() async {
    if (stage == BuilderStage.COMPILE || stage == BuilderStage.ALL) {
      var temp = new Directory(directory);

      if (temp.existsSync()) temp.deleteSync(recursive: true);
      temp.createSync();

      LOGGER.fine("Compiling w/ dart2js");
      _dart2js([
        "dump-info",
        "trust-primitives",
        "enable-experimental-mirrors"
      ], "$directory/index.js", dartFile, target, isMinified: isMinified);
    }

    if (stage == BuilderStage.WRAP || stage == BuilderStage.ALL) {
      var scraper = new Scraper(
          "$directory/index.js", "$directory/index.js.info.json",
          isMinified: isMinified);

      LOGGER.fine("Scraping dart2js output");
      var mangledNames = JSON.decode(await scraper.scrape());
      LOGGER.fine("Done scraping dart2js output");

      var compiler = new Compiler(
          dartFile, "$directory/index.js.info.json", mangledNames,
          typeTransformers: typeTransformers,
          compilerVisitors: compilerVisitors,
          isMinified: isMinified);

      LOGGER.fine("Compiling wrapper for dart2js output");
      var str = compiler.compile(include);
      str = await onWrapperGenerated(str);

      var patcher = new Patcher("$directory/index.js",
          "$directory/index.js.info.json", str.toString().split('\n'),
          target: target, isMinified: isMinified);

      LOGGER.fine("Patching wrapper into file");
      return patcher.patch();
    }

    return "";
  }

  Future<String> onWrapperGenerated(String wrapper) async {
    return wrapper;
  }
}
