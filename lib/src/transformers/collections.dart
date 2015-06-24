part of calzone.transformers;

final String _MAP_PREFIX = "var \$Map = require('es6-map');";

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionsTransformer implements TypeTransformer {
  final List<String> types = ["Map", "List"];

  final bool _usePolyfill;

  CollectionsTransformer([this._usePolyfill = false]);

  dynamicTransformTo(StringBuffer output, List<String> globals) =>
    output.write("""
      if(Array.isArray(obj)) {
        return obj.map(function(e) {
          return dynamicTo(e);
        });
      }
      if(obj.constructor.name === 'Object') {
        var elms = Object.keys(obj).reduce(function(arr, key) {
        arr.push(key); arr.push(dynamicTo(obj[key]));
          return arr;
        }, []);
        var map = new P.LinkedHashMap__makeLiteral(elms);
        map.\$builtinTypeInfo = [P.String, null];
        return map;
      }
    """);

  dynamicTransformFrom(StringBuffer output, List<String> globals) {
    output.write("""
      if(Array.isArray(obj)) {
        return obj.map(function(e) {
          return dynamicFrom(e);
        });
      }
      if(obj.constructor.name === '_JsonMap') {
        var a = obj._original;
        Object.keys(a).forEach(function(key) { a[key] = dynamicFrom(a[key]); });
        return a;
      }
      if(obj.constructor.name === 'JsLinkedHashMap') {
        var a = {};
        objEach(obj._strings, function(cell) {
          a[cell.hashMapCellKey] = dynamicFrom(cell.hashMapCellValue);
        });
        return a;
      }
    """);
  }

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name,
      List tree, List<String> globals) {
    _handleTree(tree, [name = "this[i]"]) {
      if (tree is String)
        tree = [tree];

      if (tree[0] == "Map") {
        var k = "P.String";
        var v = "null";

        if (tree.length > 2) {
          if (tree[1][0] != "dynamic") k = "init.allClasses.${tree[1][0]}";
          if (tree[2][0] != "dynamic") v = "init.allClasses.${tree[2][0]}";
        }

        var isJsMap = _usePolyfill && tree.length > 2 && tree[1] != "String";
        if (isJsMap) {
          output.write("var keys = $name.keys(); var values = $name.values();");
          output.write("keys.forEach(function(key, i) { var value = values[index];");
          _handleTree(tree[1], "values[i]");
          _handleTree(tree[2], "keys[i]");
          output.write("});");
          output.write("var elms = keys.reduce(function(arr, key, index) { arr.push(key); arr.push(values[index]); return arr; }, []);");
        } else {
          output.write("objEach($name, function(a, i) {");
          if (tree.length > 2) {
            _handleTree(tree[2]);
          } else {
            output.write("this[i] = dynamicTo(a);");
          }
          output.write("}, $name);");

          output.write("var elms = Object.keys($name).reduce(function(arr, key) { arr.push(key); arr.push($name[key]); return arr; }, []);");
        }
        output.write("$name = new P.LinkedHashMap__makeLiteral(elms);");
        output.write("$name.\$builtinTypeInfo = [$k,$v];");
      } else if (tree[0] == "List") {
        output.write("$name = [].concat($name);$name.forEach(function(a, i) {");
        if(tree.length > 1)
          _handleTree(tree[1]);
        else
          output.write("a = dynamicTo(a);");
        output.write("this[i] = a;}, $name);");
      }
    }

    _handleTree(tree, name);
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name,
      List tree, List<String> globals) {

    _handleTree(tree, [name = "this[i]"]) {
      if (tree is String)
        tree = [tree];

      if (tree[0] == "List") {
        output.write("$name = [].concat($name);$name.forEach(function(a, i) {");
        if(tree.length > 1)
          _handleTree(tree[1]);
        else
          output.write("this[i] = dynamicFrom(a);");
        output.write("}, $name);");
      } else if (tree[0] == "Map") {
        output.write("""
          if($name.constructor.name === '_JsonMap') {
            $name = $name._original;
            Object.keys($name).forEach(function(key) { $name[key] = dynamicFrom($name[key]); });
          } else {
            var keys = [];
            var values = [];
            if($name._strings) {
              objEach($name._strings, function(cell) {
                keys.push(cell.hashMapCellKey);
                values.push(cell.hashMapCellValue);
              });
            }
        """);

        var isJsMap = _usePolyfill && tree.length > 2 && tree[1] != "String";
        if (isJsMap) {
          if (!globals.contains(_MAP_PREFIX))
            globals.add(_MAP_PREFIX);
          output.write("$name = new \$Map();");
          output.write("keys.forEach(function(key, i) {");
          _handleTree(tree[1], "keys[i]");
          _handleTree(tree[2], "values[i]");
          output.write("$name.set(keys[i], values[i]); });");
        } else {
          output.write("$name = {};");
          if (tree.length > 2) {
            _handleTree(tree[2], "values");
          } else {
            output.write("values.forEach(function(key, i) { values[i] = dynamicFrom(key); });");
        }
        output.write(
            "keys.forEach(function(key, index) { $name[key] = values[index]; });");
      }
        output.write("}");
      }
    }

    _handleTree(tree, name);
  }
}
