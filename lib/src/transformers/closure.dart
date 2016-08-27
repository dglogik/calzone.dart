part of calzone.transformers;

/**
 * A transformer that will convert a JavaScript function to a closure used by
 * dart2js. This transformer requires no changes to your stub file.
 */
class ClosureTransformer implements StaticTypeTransformer, TypeTransformer {
  final List<String> types = ["Function"];
  final int maxValue;

  ClosureTransformer([this.maxValue = 10]);

  transformToDart(Compiler compiler, StringBuffer output) {
    final String prefix = compiler.isMinified ? "\$" : "call\$";
    
    output.write("""
      if (typeof obj === 'function') {
        var _function = function() {
          var args = new Array(arguments.length);
          for (var i = 0; i < args.length; ++i) {
            args[i] = dynamicFrom(arguments[i]);
          }
          return dynamicTo(obj.apply(this, args));
        };
        
        if (typeof(global.Proxy) === 'function') {
          return new Proxy({}, {
            get: function(target, name) {
              if (name.indexOf('$prefix') === 0) {
                return _function;
              }
               
              return undefined;
            }
          });
        }
                
        var returned = {};
        
        var i = 0;
        var l = $maxValue;
        for (; i < l; i++) {
          returned['$prefix' + i] = _function;
        }
        
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
