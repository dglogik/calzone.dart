part of calzone.compiler;

final RegExp _FUNCTION_REGEX = new RegExp(r"function[ a-zA-Z0-9$]*\(([, a-zA-Z0-9$_]*)\)[ ]*{");

class Func implements Renderable {
  final Map<String, dynamic> data;

  final List<Parameter> parameters;
  final FunctionTransformation transform;

  final String _code;
  final String _binding;
  final String _prefix;

  final bool _withSemicolon;

  Func(this.data, this.parameters, {this.transform: FunctionTransformation.NORMAL, String code, String binding: "this", String prefix, bool withSemicolon: true}):
    _code = code,
    _binding = binding,
    _prefix = prefix,
    _withSemicolon = withSemicolon;

  render(Compiler compiler, StringBuffer output) {
    if (_prefix == null) output.write("function(");
    else output.write("$_prefix.${data["name"]} = function(");

    var paramStringList = []..addAll(parameters);
    paramStringList.removeWhere((param) => param.kind == ParameterKind.NAMED);

    var paramString = paramStringList.map((param) => param.name).join(",");
    output.write("$paramString");
    if (parameters.any((param) => param.kind == ParameterKind.NAMED)) {
      if (paramString.length > 0) output.write(",");
      output.write("_optObj_){_optObj_ = _optObj_ || {};");
    } else {
      output.write("){");
    }

    String code = data["code"];
    if (this._code != null || code != null && code.length > 0) {
      for (var param in parameters) {
        var name = param.name;
        var declaredType = param.type;

        if (param.kind == ParameterKind.POSITIONAL) output.write("$name = $name === void 0 ? ${param.defaultValue} : $name;");
        if (param.kind == ParameterKind.NAMED) output
            .write("var $name = _optObj_.$name === void 0 ? ${param.defaultValue} : _optObj_.$name;");

        StringBuffer tOutput = new StringBuffer();

        if (transform != FunctionTransformation.REVERSED) compiler.baseTransformer.transformTo(tOutput, name, declaredType);
        else compiler.baseTransformer.transformFrom(tOutput, name, declaredType);

        if(tOutput.length > 0) {
          if(param.kind != ParameterKind.REQUIRED) {
            output.write("if($name !== null) {");
            output.write(tOutput.toString());
            output.write("}");
          } else {
            output.write(tOutput.toString());
          }
        }
      }

      code = _code != null
          ? _code
          : (code.trim().startsWith(":") == false ? "$_binding." + code.substring(0, code.indexOf(":")) : code.substring(code.indexOf(":") + 2));

      String fullParamString = parameters.map((p) => p.name).join(",");
      if(data["code"] != null && data["code"].length > 0) {
        var length = _FUNCTION_REGEX.firstMatch(data["code"]).group(1).split(',').length;
        if(length > parameters.length) {
          fullParamString = ("null," * (length - parameters.length)) + fullParamString;
        } else if(length < parameters.length) {
          throw _FUNCTION_REGEX.firstMatch(data["code"]).group(1);
        }
        if(fullParamString.endsWith(","))
          fullParamString = fullParamString.substring(0, fullParamString.length - 1);
      }

      var returnType = _TYPE_REGEX.firstMatch(data["type"]).group(2);
      compiler.baseTransformer.handleReturn(output,
          "($code).call($_binding${fullParamString.length > 0 ? "," : ""}$fullParamString)",
          returnType,
          transform: transform);

      output.write("}");

      if (_withSemicolon) output.write(";");
    }
  }
}
