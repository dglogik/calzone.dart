part of calzone.transformers;

final String _PROMISE_PREFIX = "var \$Promise = typeof(Promise) !== 'undefined' ? Promise : require('es6-promises');";

// ES6 Promise <-> Future
class PromiseTransformer implements TypeTransformer {
  final List<String> types = ["Future"];

  final bool _usePolyfill;

  PromiseTransformer([this._usePolyfill = false]);

  transformToDart(Compiler compiler, StringBuffer output) {
    var mangledNames = compiler.mangledNames;
    var data = compiler.classes["dart.async.Completer"];

    output.write("""
      if((typeof(obj) === 'object' || typeof(obj) === 'function') && typeof(obj.then) === 'function' && typeof(obj.catch) === 'function') {
        var completer = new ${mangledNames.getLibraryObject("dart.async")}.${mangledNames.getClassName("dart.async", "new Completer\$sync")}();
        obj.then(function(then) {
          completer.${data.key.getMangledName("complete")}(null, dynamicTo(then));
        }).catch(function(err) {
          completer.${data.key.getMangledName("completeError")}(err);
        });
        return completer.future;
      }
    """);
  }

  transformFromDart(Compiler compiler, StringBuffer output) {
    var promiseName = _usePolyfill ? "\$Promise" : "Promise";
    if (_usePolyfill) {
      if (!compiler.globals.contains(_PROMISE_PREFIX))
        compiler.globals.add(_PROMISE_PREFIX);
    }

    output.write("""
      if(obj.constructor.name === "_Future") {
        var promise = new $promiseName(function(then, error) {
          obj.then\$2\$onError({
            call\$1:function(val) {
              then(dynamicFrom(val));
            }
          }, {
            call\$1: function(err) {
              error(err);
            }
          });
        });
        return promise;
      }
    """);
  }
}
