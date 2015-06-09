part of calzone.transformers;

final String _PROMISE_PREFIX = "var \$Promise = require('es6-promises');";

// ES6 Promise <-> Future
class PromiseTransformer implements TypeTransformer {
  final List<String> types = ["Future"];

  final bool _usePolyfill;

  PromiseTransformer([this._usePolyfill = false]);

  dynamicTransformTo(StringBuffer output, List<String> globals) =>
    output.write("""
      if(obj instanceof \$Promise) {
        var completer = new P._SyncCompleter(new P._Future(0, \$.Zone__current, null));
        obj.then(function(then) {
          completer.complete\$1(dynamicTo(then));
        }).catch(function(err) {
          completer.completeError\$1(err);
        });
        return completer.future;
      }
    """);

  dynamicTransformFrom(StringBuffer output, List<String> globals) {
    var promiseName = "Promise";
    if(_usePolyfill) {
      if(!globals.contains(_PROMISE_PREFIX))
        globals.add(_PROMISE_PREFIX);
      promiseName = "\$Promise";
    }

    output.write("""
      if(obj.constructor.name === "_Future") {
        var promise = new $promiseName(function(then, error) {
          obj.then\$2\$onError({
            call\$1:function(val) {
              transformFrom(val);
              then(val);
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

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    output.write("var completer = new P._SyncCompleter(new P._Future(0, \$.Zone__current, null));");
    output.write("$name.then(function(then) {");
    if(tree.length > 1)
      base.transformToDart(output, base, "then", tree[1], globals);
    output.write("completer.complete\$1(then);}).catch(function(err) {completer.completeError\$1(err);});");
    output.write("$name = completer.future;");
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    if(_usePolyfill && !globals.contains(_PROMISE_PREFIX))
      globals.add(_PROMISE_PREFIX);

    output.write("var promise = new ${_usePolyfill ? "\$Promise" : "Promise"}(function(then, error) {$name.then\$2\$onError({call\$1:function(val) {");
    if(tree.length > 1)
      base.transformFromDart(output, base, "val", tree[1], globals);
    output.write("then(val); }}, {call\$1: function(err) {error(err);}});});");
    output.write("$name = promise;");
  }
}
