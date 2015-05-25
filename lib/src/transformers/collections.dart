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

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionTransformer implements TypeTransformer {
  final List<String> types = ["Map", "List"];

  CollectionTransformer();

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    _handleTree(tree) {
      if (tree[0] == "Map") {
        if (tree.length > 2) {
          if (!globals.contains(_OBJ_EACH_PREFIX))
            globals.add(_OBJ_EACH_PREFIX);
          output.write("objEach(a, function(a, i) {");
          // _handleTree(tree[1]);
          _handleTree(tree[2]);
          output.write("}, a);");
        }

        var k = "P.String";
        var v = "null";

        if (tree.length > 2) {
          if (tree[1][0] != "dynamic") k = "init.allClasses.${tree[1][0]}";
          if (tree[2][0] != "dynamic") v = "init.allClasses.${tree[2][0]}";
        }

        output.write(
            "var elms = Object.keys(a).reduce(function(arr, key) { arr.push(key); arr.push(a[key]); return arr; }, []);");
        output.write(
            "this[i] = new P.LinkedHashMap_LinkedHashMap\$_literal(elms,$k,$v);");
      } else if (tree[0] == "List" && tree.length > 1) {
        output.write("a.forEach(function(a, i) {");
        _handleTree(tree[1]);
        output.write("}, a);");
      } else {
        base.transformToDart(output, base, "this[i]", tree[0], globals);
      }
    }

    if (tree[0] == "Map") {
      if (tree.length > 2) {
        if (!globals.contains(_OBJ_EACH_PREFIX))
          globals.add(_OBJ_EACH_PREFIX);
        output.write("objEach($name, function(a, i) {");
        // _handleTree(tree[1]);
        _handleTree(tree[2]);
        output.write("}, $name);");
      }

      var k = "P.String";
      var v = "null";

      if (tree.length > 2) {
        if (tree[1][0] != "dynamic") k = "init.allClasses." + tree[1][0];
        if (tree[2][0] != "dynamicnew P._AsyncCompleter") v = "init.allClasses." + tree[2][0];
      }

      output.write(
          "var elms = Object.keys($name).reduce(function(arr, key) { arr.push(key); arr.push($name[key]); return arr; }, []);");
      output.write(
          "$name = new P.LinkedHashMap_LinkedHashMap\$_literal(elms,$k,$v);");
    } else if (tree[0] == "List" && tree.length > 1) {
      output.write("$name.forEach(function(a, i) {");
      _handleTree(tree[1]);
      output.write("}, $name);");
    }
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    _handleTree(tree, [binding = "a"]) {
      if (tree[0] == "List" && tree.length > 1) {
        output.write("this[i] = a.map(function(a, i) {");
        _handleTree(tree[1]);
        output.write("}, $binding);");
      } else if (tree[0] == "Map") {
        output.write("$binding = (function(a) {");
        output.write(
            "var keys = a.get\$keys(); var values = a.get\$values(); a = {};");
        if (tree.length > 2) _handleTree(tree[2], "a");
        output.write(
            "keys.forEach(function(key, index) { a[key] = values[index]; });");
        output.write("return a;");
        output.write("}($binding))");
      } else {
        base.transformFromDart(output, base, "this[i]", tree[0], globals);
      }
    }

    if (tree[0] == "List" && tree.length > 1) {
      output.write("$name = $name.forEach(function(a, i) {");
      _handleTree(tree[1]);
      output.write("}, $name);");
    } else if (tree[0] == "Map") {
      // TODO: ES6 Maps.
      // TODO: K of Map being non-String (requires ES6 Maps)
      output.write(
          "var keys = $name.get\$keys(); var values = $name.get\$values(); $name = {};");
      if (tree.length > 2) _handleTree(tree[2], "values");
      output.write(
          "keys.forEach(function(key, index) { $name[key] = values[index]; });");
    }
  }
}
