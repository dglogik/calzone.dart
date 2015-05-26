part of calzone.transformers;

final String _OBJ_EACH_PREFIX = """
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
""";

final String _MAP_PREFIX = "var \$Map = require('es6-map');";

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionsTransformer implements TypeTransformer {
  final List<String> types = ["Map", "List"];

  final bool _usePolyfill;

  CollectionsTransformer([this._usePolyfill = false]);

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    _handleTree(tree, [binding = "a", thisObj = "this"]) {
      if (tree[0] == "Map") {
        var k = "P.String";
        var v = "null";

        if (tree.length > 2) {
          if (tree[1][0] != "dynamic") k = "init.allClasses.${tree[1][0]}";
          if (tree[2][0] != "dynamic") v = "init.allClasses.${tree[2][0]}";
        }

        var isJsMap = _usePolyfill && tree.length > 2 && tree[1] != "String";
        if(isJsMap) {
          output.write("var keys = $binding.keys(); var values = $binding.values();");
          output.write("keys.forEach(function(key, i) { var value = values[index];");
          _handleTree(tree[1], "value");
          _handleTree(tree[2], "key", "keys");
          output.write("}, values);");
          output.write("var elms = keys.reduce(function(arr, key, index) { arr.push(key); arr.push(values[index]); return arr; }, []);");
        } else {
          if(tree.length > 2) {
            if (!globals.contains(_OBJ_EACH_PREFIX))
              globals.add(_OBJ_EACH_PREFIX);
            output.write("objEach($binding, function(a, i) {");
            _handleTree(tree[2]);
            output.write("}, $binding);");
          }

          output.write("var elms = Object.keys($binding).reduce(function(arr, key) { arr.push(key); arr.push($binding[key]); return arr; }, []);");
        }
        output.write("$thisObj[i] = new P.LinkedHashMap_LinkedHashMap\$_literal(elms,$k,$v);");
      } else if (tree[0] == "List" && tree.length > 1) {
        output.write("$binding.forEach(function(a, i) {");
        _handleTree(tree[1]);
        output.write("}, $binding);");
      } else {
        base.transformToDart(output, base, "$thisObj[i]", tree[0], globals);
      }
    }

    if (tree[0] == "Map") {
      var k = "P.String";
      var v = "null";

      if (tree.length > 2) {
        if (tree[1][0] != "dynamic") k = "init.allClasses.${tree[1][0]}";
        if (tree[2][0] != "dynamic") v = "init.allClasses.${tree[2][0]}";
      }

      var isJsMap = _usePolyfill && tree.length > 2 && tree[1] != "String";
      if(isJsMap) {
        output.write("var keys = $name.keys(); var values = $name.values();");
        output.write("keys.forEach(function(key, i) { var value = values[index];");
        _handleTree(tree[1], "value");
        _handleTree(tree[2], "key", "keys");
        output.write("}, values);");
        output.write("var elms = keys.reduce(function(arr, key, index) { arr.push(key); arr.push(values[index]); return arr; }, []);");
      } else {
        if(tree.length > 2) {
          if (!globals.contains(_OBJ_EACH_PREFIX))
            globals.add(_OBJ_EACH_PREFIX);
          output.write("objEach($name, function(a, i) {");
          _handleTree(tree[2]);
          output.write("}, $name);");
        }

        output.write("var elms = Object.keys($name).reduce(function(arr, key) { arr.push(key); arr.push($name[key]); return arr; }, []);");
      }
      output.write("$name = new P.LinkedHashMap_LinkedHashMap\$_literal(elms,$k,$v);");
    } else if (tree[0] == "List" && tree.length > 1) {
      output.write("$name.forEach(function(a, i) {");
      _handleTree(tree[1]);
      output.write("}, $name);");
    }
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    _handleTree(tree, [binding = "a", thisObj = "this"]) {
      if (tree[0] == "List" && tree.length > 1) {
        output.write("$thisObj[i] = a.map(function(a, i) {");
        _handleTree(tree[1]);
        output.write("}, $binding);");
      } else if (tree[0] == "Map") {
        output.write("this[i] = (function(a) {");
        output.write("var keys = a.get\$keys(); var values = a.get\$values();");

        var isJsMap = _usePolyfill && tree.length > 2 && tree[1] != "String";
        if(isJsMap) {
          if(!globals.contains(_MAP_PREFIX))
            globals.add(_MAP_PREFIX);
          output.write("a = new \$Map();");
          output.write("keys.forEach(function(key, index) { var value = values[index];");
          _handleTree(tree[1], "key");
          _handleTree(tree[2], "value");
          output.write("a.set(key, values[index]); });");
        } else {
          output.write("a = {};");
          if (tree.length > 2)
            _handleTree(tree[2], "values");
          output.write("keys.forEach(function(key, index) { a[key] = values[index]; });");
        }
        output.write("return a");
        output.write("}($binding));");
      } else {
        base.transformFromDart(output, base, "this[i]", tree[0], globals);
      }
    }

    if (tree[0] == "List" && tree.length > 1) {
      output.write("$name = $name.forEach(function(a, i) {");
      _handleTree(tree[1]);
      output.write("}, $name);");
    } else if (tree[0] == "Map") {
      output.write("var keys = $name.get\$keys(); var values = $name.get\$values();");

      var isJsMap = _usePolyfill && tree.length > 2 && tree[1] != "String";
      if(isJsMap) {
        if(!globals.contains(_MAP_PREFIX))
          globals.add(_MAP_PREFIX);
        output.write("$name = new \$Map();");
        output.write("keys.forEach(function(key, index) { var value = values[index];");
        _handleTree(tree[1], "key");
        _handleTree(tree[2], "value");
        output.write("$name.set(key, values[index]); });");
      } else {
        output.write("$name = {};");
        if (tree.length > 2)
          _handleTree(tree[2], "values");
        output.write("keys.forEach(function(key, index) { $name[key] = values[index]; });");
      }
    }
  }
}
