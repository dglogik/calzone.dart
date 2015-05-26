part of calzone.transformers;

final String _PROMISE_PREFIX = "var \$Promise = require('es6-promises');";

// ES6 Promise <-> Future
class PromiseTransformer implements TypeTransformer {
  final List<String> types = ["Future"];

  final bool _usePolyfill;

  PromiseTransformer([this._usePolyfill = false]);

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    output.write("var completer = new P._AsyncCompleter(new P._Future(0, \$.Zone__current, null))");
    output.write("$name.then((then) {");
    if(tree.length > 1)
      base.transformToDart(output, base, "then", tree[1], globals);
    output.write("completer.complete\$1(then);}).catch(function(err) {completer.completeError\$1(err};)");
    output.write("$name = completer.future");
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    if(_usePolyfill && !globals.contains(_PROMISE_PREFIX))
      globals.add(_PROMISE_PREFIX);

    output.write("var promise = new ${_usePolyfill ? "\$Promise" : "Promise"}(function(then, error) {$name.then\$2\$onError({call\$1:function(val) {");
    if(tree.length > 1)
      base.transformFromDart(output, base, "val", tree[1], globals);
    output.write("then(val); }}, {call\$1: function(err) {error(err);}})});");
    output.write("$name = promise;");
  }
}