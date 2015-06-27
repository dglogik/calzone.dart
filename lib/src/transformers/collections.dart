part of calzone.transformers;

final String _MAP_PREFIX = "var \$Map = require('es6-map');";

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionsTransformer implements TypeTransformer {
  final List<String> types = ["Map", "List"];

  final bool _usePolyfill;

  CollectionsTransformer([this._usePolyfill = false]);

  transformToDart(Compiler compiler, StringBuffer output) {
    var mangledNames = compiler.mangledNames;
    var constructor = mangledNames.getClassName("dart.collection", "new LinkedHashMap\$fromIterables");

    output.write("""
      if(Array.isArray(obj)) {
        return obj.map(function(e) {
          return dynamicTo(e);
        });
      }
      if(obj.constructor.name === 'Object') {
        var keys = Object.keys(obj);
        var values = [];
        keys.forEach(function(_, key) {
          values.push(dynamicTo(obj[key]));
        });

        var map = new ${mangledNames.getLibraryObject("dart.collection")}.$constructor(keys, values);
        map.\$builtinTypeInfo = [${compiler.mangledNames.getLibraryObject("dart.core")}.${compiler.mangledNames.getClassName("dart.core", "String")}, null];
        return map;
      }
    """);
  }

  transformFromDart(Compiler compiler, StringBuffer output) {
    var data = compiler.classes["_js_helper.JsLinkedHashMap"];

    output.write("""
      if(Array.isArray(obj)) {
        return obj.map(function(e) {
          return dynamicFrom(e);
        });
      }

      if(obj.${data.key.getMangledName("keys")} && obj.${data.key.getMangledName("values")}) {
        var keys = obj.${data.key.getMangledName("keys")}();
        var values = obj.${data.key.getMangledName("values")}();

        var a = {};
        keys.forEach(function(key, index) {
          a[key] = dynamicFrom(values[index]);
        });

        return a;
      }
    """);
  }
}
