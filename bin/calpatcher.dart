library calpatcher;

import "package:args/args.dart";

import "dart:io";
import "dart:convert";

main(List<String> args) async {
  var parser = new ArgParser();

  parser.addOption("target",
      abbr: "t", defaultsTo: "browser", allowed: ["browser", "node"]);
  parser.addOption("file", abbr: "f");
  parser.addOption("wrapper", abbr: "w");
  parser.addOption("info", abbr: "i");
  parser.addFlag("minified", abbr: "m", defaultsTo: false);

  if (args.length == 0) {
    print(parser.usage);
    return;
  }

  var results = parser.parse(args);
  var file = new File(results["file"]);

  List<String> data = file.readAsLinesSync();

  if (results["target"] == "node") {
    // node preamble
    data.insert(0, """
global.location = { href: "file://" + process.cwd() + "/" };
global.scheduleImmediate = setImmediate;
global.self = global;
global.require = require;
global.process = process;

global.dartMainRunner = function(main, args) {
  main(args.slice(Math.min(args.length, 2)));
};

// Support for deferred loading.
global.dartDeferredLibraryLoader = function(uri, successCallback, errorCallback) {
  try {
    load(uri);
    successCallback();
  } catch (error) {
    errorCallback(error);
  }
};
    """);
  }

  var index = data.length;
  var reversed = []..addAll(data.reversed);

  var foundTypeCheck = false;
  var foundMain = false;

  if(results["minified"]) {
    var json = JSON.decode(new File(results["info"]).readAsStringSync());

    var main = "main";
    var _isTest = "_isTest";

    _iterate(number) {
      var iter = json["elements"]["library"][number]["children"].where((child) => child.contains("function"));
      iter = iter.toList();

      var classes = json["elements"]["library"][number]["children"].where((child) => child.contains("class"));

      for(var c in classes) {
        c = c.split("/");

        var type = c[0];
        var id = c[1];

        var data = json["elements"][type][id];

        iter.addAll(data["children"].where((child) => child.contains("function")));
      }

      for(var func in iter) {
        func = func.split("/");

        var type = func[0];
        var id = func[1];

        var childData = json["elements"][type][id];

        if(childData["name"] == "main")
          main = childData["code"].split(":")[0].trim();

        if(childData["name"] == "_isTest") {
          _isTest = childData["code"].split(":")[0].trim();
        }
      }
    }

    for(var library in json["elements"]["library"].values) {
      if(library["id"] == "library/0") {
        _iterate("0");
      }

      if(library["name"] == "_js_helper") {
        _iterate(library["id"].split("/")[1]);
        break;
      }
    }

    for (var line in reversed) {
      index--;
      if (line.endsWith('})()') && data.length - index < 4) {
        data[index] = line.substring(0, line.length - 4) + ';';
        data.insertAll(index + 1, new File(results["wrapper"]).readAsLinesSync()..add('})()'));
      }

      if (line.startsWith("$_isTest:")) {
        data[index + 1] = "return true},";
        foundTypeCheck = true;
        if(foundMain && foundTypeCheck)
          break;
      }

      if (line.startsWith("$main:")) {
        data.replaceRange(index, index + 3, ["Q:[function(a){},\"\$1\",\"ao\",2,0,279],"]);
        foundMain = true;
        if(foundMain && foundTypeCheck)
          break;
      }
    }
  } else {
    for (var line in reversed) {
      index--;
      if (line.contains("// END invoke [main].")) {
        data.insertAll(index, new File(results["wrapper"]).readAsLinesSync());
        continue;
      }

      if (line.contains("buildFunctionType: function(returnType, parameterTypes, optionalParameterTypes) {")) {
        data[index + 1] = "var proto = Object.create(new H.RuntimeFunctionType(returnType, parameterTypes, optionalParameterTypes, null)); proto._isTest\$1 = function() { return true; }; return proto;";
        foundTypeCheck = true;
        if(foundMain && foundTypeCheck)
          break;
      }

      if (line.contains("main: [function(args) {")) {
        data.removeRange(index + 1, index + 4);
        foundMain = true;
        if(foundMain && foundTypeCheck)
          break;
      }
    }
  }

  print(data.join("\n"));
}
