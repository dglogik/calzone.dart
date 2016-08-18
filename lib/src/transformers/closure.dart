part of calzone.transformers;

/**
 * A transformer that will convert a JavaScript function to a closure used by
 * dart2js. This transformer requires no changes to your stub file.
 */
class ClosureTransformer implements StaticTypeTransformer, TypeTransformer {
  final List<String> types = ["Function"];

  ClosureTransformer();

  transformToDart(Compiler compiler, StringBuffer output) {
    output.write(r"""
      if(typeof obj === 'function') {
        var argCount = (new RegExp(/function[ a-zA-Z0-9$]*\(([, a-zA-Z0-9$_]*)\)[ ]*{/))
          .exec(obj.toString())[1]
          .split(',')
          .filter(function(arg) {
            return arg.trim().length > 0;
          })
          .length;
    """);

    output.write("""
        var returned = {};
        returned['${compiler.isMinified ? "\$" : "call\$"}' + argCount] = function() {
          var args = new Array(arguments.length);
          for(var i = 0; i < args.length; ++i) {
            args[i] = dynamicFrom(arguments[i]);
          }
          return dynamicTo(obj.apply(this, args));
        };
        return returned;
      }
    """);
  }

  // TODO
  transformFromDart(Compiler compiler, StringBuffer output) {}

  staticTransformTo(
      Compiler compiler, StringBuffer output, String name, List tree) {
    if (tree.length < 2) return;

    List<List> types = tree.sublist(1, tree.length - 1);
    output.write("""
      var _${name}_ = $name;
      $name = {
        ${compiler.isMinified ? "\$${types.length}" : "call\$${types.length}"}: function() {
          var args = new Array(arguments.length);
          for(var i = 0; i < args.length; ++i) {
            args[i] = dynamicFrom(arguments[i]);
          }
          return dynamicFrom(_${name}_.apply(this, args));
        }
      };
    """);
  }

  // TODO
  staticTransformFrom(
      Compiler compiler, StringBuffer output, String name, List tree) {}
}
