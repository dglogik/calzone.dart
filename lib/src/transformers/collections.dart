part of calzone.transformers;

final String _MAP_PREFIX = "var \$Map = require('es6-map');";

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionsTransformer implements TypeTransformer {
  final List<String> types = ["Map", "List"];

  final bool _usePolyfill;

  CollectionsTransformer([this._usePolyfill = false]);

  transformToDart(Compiler compiler, StringBuffer output) {
    var mangledNames = compiler.mangledNames;
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
        map.\$builtinTypeInfo = [${compiler.mangledNames.getLibraryObject("dart.core")}.${compiler.mangledNames.getClassName("dart.core", "String")}, null];
        return map;
      }
    """);
  }

  transformFromDart(Compiler compiler, StringBuffer output) {
    var jsonData = compiler.classes["dart.convert._JsonMap"];
    var linkedData = compiler.classes["_js_helper.JsLinkedHashMap"];

    output.write("""
      if(Array.isArray(obj)) {
        return obj.map(function(e) {
          return dynamicFrom(e);
        });
      }
      var keys;
      var values;
      if(${jsonData.key.renderConditional("obj")}) {
        keys = obj.${jsonData.key.getMangledName("keys")}();
        values = obj.${jsonData.key.getMangledName("values")}();
      }
      if(${linkedData.key.renderConditional("obj")}) {
        keys = obj.${linkedData.key.getMangledName("keys")}();
        values = obj.${linkedData.key.getMangledName("values")}();
      }

      var a = {};
      keys.forEach(function(key, index) {
        a[key] = dynamicFrom(values[index]);
      });

      return a;
    """);
  }
}
