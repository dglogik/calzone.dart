library calzone.patcher;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:node_preamble/preamble.dart" as preamble;

var _SCRAPER = r"""
function objEach(obj, cb, thisArg) {
  if(typeof thisArg !== 'undefined') {
    cb = cb.bind(thisArg);
  }

  var count = 0;
  var keys = Object.keys(obj);
  var length = keys.length;

  for(; count < length; count++) {
    var key = keys[count];
    cb(obj[key], key, obj);
  }
}

var map = {
  libraries: {}
};

var regex = new RegExp("[A-Za-z_0-9]+(?=[^:A-Za-z,]|$),*", "g");

var staticFields = typeof(Isolate) !== "undefined" ? Isolate.$isolateProperties : I.p;
var staticFieldKeys = Object.keys(staticFields);

var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

init.libraries.forEach(function(elm) {
  var library = {
    names: {},
    staticFields: {}
  };

  var length = elm.length;
  elm.forEach(function(elm, index) {
    if(index == 0) {
      library.name = elm;
    }

    if(index === 5 && elm != null && elm.toString() === elm) {
      var field = regex.exec(elm);
      while(field != null) {
        field = field[0];
        if(staticFieldKeys.indexOf(field) >= 0) {
          library.staticFields[init.mangledGlobalNames[field]] = field;
        }
        field = regex.exec(elm);
      }
    }

    if(index === length - 1) {
      var alphadex = 25;
      while(--alphadex >= 0) {
        if(eval("typeof(" + alphabet[alphadex] + ")") === "object" && eval(alphabet[alphadex]) === elm)
          library.obj = alphabet[alphadex];
      }
    }

    if(Array.isArray(elm)) {
      elm.forEach(function(name) {
        if(init.allClasses[name] && init.mangledGlobalNames[name]) {
          library.names[init.mangledGlobalNames[name] || name] = {
            name: name,
            fields: init.allClasses[name]['$__fields__'],
          };

          if(init.statics[name] && init.statics[name]['^']) {
            var names = init.statics[name]['^'];

            var field = regex.exec(names);
            while(field != null) {
              field = field[0];
              if(staticFieldKeys.indexOf(field) >= 0) {
                library.staticFields[init.mangledGlobalNames[name] + '.' + init.mangledGlobalNames[field]] = field;
              }
              field = regex.exec(names);
            }
          }
        } else if(init.mangledGlobalNames[name] && init.mangledGlobalNames[name].indexOf('new ') === 0) {
          library.names[init.mangledGlobalNames[name].split(':')[0]] = {
            name: name
          };
        }
      });
    }
  });

  map.libraries[library.name] = library;
});

console.log(JSON.stringify(map));
""";

class PatcherTarget {
  static const PatcherTarget NODE = const PatcherTarget._("node");
  static const PatcherTarget BROWSER = const PatcherTarget._("browser");

  final String _name;

  const PatcherTarget._(this._name);

  static PatcherTarget fromString(String str) {
    if (str == "node") return PatcherTarget.NODE;
    if (str == "browser") return PatcherTarget.BROWSER;
    throw new StateError("unknown target");
  }

  String toString() => this._name;
}

// the ugly part of calzone
class Patcher {
  final PatcherTarget target;
  final bool isMinified;

  final List<String> _compiledFile;
  final Map<String, dynamic> _infoFile;
  final List<String> _wrapperFile;

  Patcher(dynamic compiledFile, dynamic infoFile, dynamic wrapperFile,
      {this.target: PatcherTarget.BROWSER, this.isMinified: false})
      : _compiledFile = compiledFile is String ? new File(compiledFile).readAsLinesSync() : compiledFile.split("\n"),
        _infoFile = infoFile is String ? JSON.decode(new File(infoFile).readAsStringSync()) : infoFile,
        _wrapperFile = wrapperFile is String ? new File(wrapperFile).readAsLinesSync() : wrapperFile;

  String patch() {
    var data = _compiledFile;

    if (target == PatcherTarget.NODE) {
      // node preamble
      data.insert(0, preamble.getPreamble());
    }

    var index = data.length;
    var reversed = []..addAll(data.reversed);

    if (isMinified) {
      var json = _infoFile;

      var main = "main";

      _iterate(number) {
        var iter = json["elements"]["library"][number]["children"].where((child) => child.contains("function"));
        iter = iter.toList();

        var classes = json["elements"]["library"][number]["children"].where((child) => child.contains("class"));

        for (var c in classes) {
          c = c.split("/");

          var type = c[0];
          var id = c[1];

          var data = json["elements"][type][id];

          iter.addAll(data["children"].where((child) => child.contains("function")));
        }

        for (var func in iter) {
          func = func.split("/");

          var type = func[0];
          var id = func[1];

          var childData = json["elements"][type][id];

          if (childData["name"] == "main") {
            main = childData["code"].split(":")[0].trim();
            return true;
          }
        }

        return false;
      }

      for (var library in json["elements"]["library"].values) {
        if (_iterate(library["id"].split("/")[1])) {
          break;
        }
      }

      for (var line in reversed) {
        index--;
        if (line.endsWith('})()') && data.length - index < 4) {
          data[index] = line.substring(0, line.length - 4) + ';';
          data.insertAll(
              index + 1,
              []
                ..addAll(_wrapperFile)
                ..add('})()'));
        }

        if (line.startsWith("$main:")) {
          data[index + 6] = data[index + 6].substring(data[index + 6].indexOf("}") + 2);
          data.replaceRange(index, index + 6, ["$main:[function(a){},"]);
          break;
        }
      }
    } else {
      for (var line in reversed) {
        index--;
        if (line.contains("// END invoke [main].")) {
          data.insertAll(index, _wrapperFile);
          continue;
        }

        if (line.contains("main: [function(args) {")) {
          data.removeRange(index + 1, index + 8);
          break;
        }
      }
    }

    return data.join("\n");
  }
}

class Scraper extends Patcher {
  Scraper(dynamic compiledFile, dynamic infoFile, {isMinified: false})
      : super(compiledFile, infoFile, _SCRAPER.split("\n"), target: PatcherTarget.NODE, isMinified: isMinified);

  Future<String> scrape() async {
    var patch = super.patch();

    var process = await Process.start("node", []);
    process.stdin.write(patch);
    await process.stdin.flush();
    process.stdin.close();

    String returned = "";

    await process.stdout.forEach((data) => returned += UTF8.decode(data));
    await process.stderr.forEach((data) => stderr.writeln(UTF8.decode(data)));

    return returned;
  }
}
