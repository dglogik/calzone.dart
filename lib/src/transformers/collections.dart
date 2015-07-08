part of calzone.transformers;

final String _MAP_PREFIX = "var \$Map = require('es6-map');";

// ES6-like Maps and Objects to Dart Maps, Arrays to Lists
class CollectionsTransformer implements TypeTransformer {
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

        keys.forEach(function(key) {
          values.push(dynamicTo(obj[key]));
        });

        var map = new ${mangledNames.getLibraryObject("dart.collection")}.$constructor(keys, values);
        map.\$builtinTypeInfo = [${compiler.mangledNames.getLibraryObject("dart.core")}.${compiler.mangledNames.getClassName("dart.core", "String")}, null];
        return map;
      }

      // effectively a ES6 Map
      if(obj.forEach
          && obj.get
          && obj.has
          && obj.set
          && obj.keys
          && obj.values) {
        var keys = [];
        var values = [];

        obj.forEach(function(value, key) {
          keys.push(dynamicTo(key));
          values.push(dynamicTo(value));
        });

        var map = new ${mangledNames.getLibraryObject("dart.collection")}.$constructor(keys, values);
        map.\$builtinTypeInfo = [null, null];
        return map;
      }
    """);
  }

  transformFromDart(Compiler compiler, StringBuffer output) {
    var data = compiler.classes["_js_helper.JsLinkedHashMap"];

    var listClass = compiler.classes["dart.core.Iterable"].key;
    var forEach = listClass.getMangledName("forEach");
    var elementAt = listClass.getMangledName("elementAt");

    output.write("""
      if(Array.isArray(obj)) {
        return obj.map(function(e) {
          return dynamicFrom(e);
        });
      }

      if(obj.${data.key.getMangledName("keys")} && obj.${data.key.getMangledName("values")}) {
        var keys = obj.${data.key.getMangledName("keys")}();
        var values = obj.${data.key.getMangledName("values")}();

        var index = 0;
        var a = {};

        keys.$forEach(null, {
          ${compiler.isMinified ? "\$1" : "call\$1"}: function(key) {
            a[dynamicFrom(key)] = dynamicFrom(values.$elementAt(null, index));
            index++;
          }
        });

        return a;
      }
    """);
  }
}
