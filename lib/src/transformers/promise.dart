part of calzone.transformers;

final String _PROMISE_PREFIX =
    "var \$Promise = typeof(Promise) !== 'undefined' ? Promise : require('es6-promises');";

/**
 * A transformer that handles converting between Dart's Future and Promises.
 *
 * To use this transformer, you need to import "dart:async" into your stub file,
 * and add "dart.async.Completer" and "dart.async.Future", to your @MirrorsUsed
 * declaration.
 *
 * If a bool is provided to this class's constructor, you need to
 * be using a CommonJS/npm environment with the es6-promises package in your
 * package.json.
 */
class PromiseTransformer implements TypeTransformer {
  final bool _usePolyfill;

  PromiseTransformer([this._usePolyfill = false]);

  transformToDart(Compiler compiler, StringBuffer output) {
    var mangledNames = compiler.mangledNames;
    var classData = compiler.classes["dart.async._Completer"];
    var data = compiler.classes["dart.async._SyncCompleter"];

    var future = classData.key.getField("future",
        compiler.analyzer.getClass("dart.async", "Completer"),
        mangledNames.getClassFields("dart.async", compiler.isMinified
            ? "Pf" : "_Completer"));

    output.write("""
      if(obj && typeof(obj.then) === 'function' && typeof(obj.catch) === 'function') {
        var completer = new ${mangledNames.getLibraryObject("dart.async")}.${mangledNames.getClassName("dart.async", "new Completer\$sync")}();
        obj.then(function(then) {
          completer.${data.key.getMangledName("complete")}(null, dynamicTo(then));
        }).catch(function(err) {
          completer.${data.key.getMangledName("_completeError")}(err);
        });
        return completer.$future;
      }
    """);
  }

  transformFromDart(Compiler compiler, StringBuffer output) {
    var promiseName = _usePolyfill ? "\$Promise" : "Promise";
    if (_usePolyfill)
      compiler.globals.add(_PROMISE_PREFIX);

    var data = compiler.classes["dart.async._Future"];

    output.write("""
      if(${data.key.renderConditional("obj")}) {
        var promise = new $promiseName(function(then, error) {
          obj.${data.key.getMangledName("then")}({
            ${compiler.isMinified ? "\$1" : "call\$1"}:function(val) {
              then(dynamicFrom(val));
            }
          }, {
            ${compiler.isMinified ? "\$1" : "call\$1"}: function(err) {
              error(err);
            }
          });
        });
        return promise;
      }
    """);
  }
}
