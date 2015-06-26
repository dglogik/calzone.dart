part of calzone.transformers;

final String _MAP_PREFIX = "var \$Map = require('es6-map');";

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionsTransformer implements TypeTransformer {
  final List<String> types = ["Map", "List"];

  final bool _usePolyfill;

  CollectionsTransformer([this._usePolyfill = false]);

  transformToDart(Compiler compiler, StringBuffer output) {
    var mangledNames = compiler.mangledNames;
    var data = compiler.classes["dart.collection.LinkedHashMap"];
    var constructor = mangledNames.getClassName("dart.collection", "new LinkedHashMap\$fromIterable");

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
        var map = new ${mangledNames.getLibraryObject("dart.collection")}.$constructor(elms);
        map.\$builtinTypeInfo = [P.String, null];
        return map;
      }
    """);
  }

  transformFromDart(Compiler compiler, StringBuffer output) {
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
}
