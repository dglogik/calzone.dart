part of calzone.transformers;

// Closure transformer to Dart closures
class ClosureTransformer implements StaticTypeTransformer, TypeTransformer {
  final List<String> types = ["Function"];

  ClosureTransformer();

  transformToDart(Compiler compiler, StringBuffer output) {
    output.write("""
      if(typeof obj === 'function') {
        var argCount = (new RegExp(/function[^]*\(([^]*)\)/))
          .exec(obj.toString())[1]
          .split(',')
          .filter(function(arg) {
            return arg.length > 0;
          })
          .length;
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

  staticTransformTo(Compiler compiler, StringBuffer output, String name, List tree) {
    if(tree.length < 2) {
      output.write("$name = dynamicTo($name);");
      return;
    }

    List<List> types = tree.sublist(1, tree.length - 1);
    output.write("""
      $name = {
        call\$${types.length}: function() {
          var args = new Array(arguments.length);
          for(var i = 0; i < args.length; ++i) {
            args[i] = dynamicFrom(arguments[i]);
          }
          return dynamicFrom($name.apply(this, arguments));
        }
      };
    """);
  }

  // TODO
  staticTransformFrom(Compiler compiler, StringBuffer output, String name, List tree) {}
}
