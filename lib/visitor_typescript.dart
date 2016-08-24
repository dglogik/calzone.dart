library calzone.visitor_typescript;

import "package:analyzer/analyzer.dart" show ParameterKind;

import "package:calzone/compiler.dart";
import "package:calzone/util.dart";

final Map<dynamic, String> _baseTypes = <String, String>{
  null: "void",
  "dynamic": "any",
  "String": "string",
  "bool": "boolean",
  "int": "number",
  "num": "number",
  "Map": "any",
  "LinkedHashMap": "any",
  "Function": "any"
};

class _DualStringBuffer {
  StringBuffer prefix = new StringBuffer();
  StringBuffer content = new StringBuffer();
  
  _DualStringBuffer();
  
  writelnPrefix(String text) => prefix.writeln(text);
  
  writeln(String text) => content.writeln(text);
  
  String toString() {
    if (prefix.isEmpty) {
      return content.toString();
    }
    
    return "${prefix}\n\n${content}";
  }
}

class TypeScriptCompilerVisitor extends CompilerVisitor {
  final String moduleName;
  
  String _output;
  String get output => _output;
  bool get hasOutput => _output != null;
    
  StringBuffer _buffer;
  
  _DualStringBuffer _classBuffer;
  String _className;
  
  Map<dynamic, String> _types; 
  
  TypeScriptCompilerVisitor(this.moduleName);
  
  startCompilation(Compiler compiler) {
    _buffer = new StringBuffer();
    _buffer.writeln("declare namespace __$moduleName {");
    
    _types = new Map.from(_baseTypes);
    
    for (TypeTransformer transformer in compiler.typeTransformers) {
      if (transformer is! NamedTypeTransformer)
        continue;

      var n = transformer as NamedTypeTransformer;
      for (var input in n.types) {
          _types[input] = n.output;
      }
    }
  }
  
  stopCompilation() {
    _buffer.writeln("""
}
      
declare module "$moduleName" {
\texport = __$moduleName;
}
    """);
    
    _output = _buffer.toString();
    _buffer = null;
  }
  
  String _handleType(String type) {
    var tree = getTypeTree(type);

    if (_types.containsKey(tree[0])) {
      return _types[tree[0]];
    }
        
    if (tree[0] == "List" || tree[0] == "Iterable") {
      if (tree.length > 1) {
        return "${_handleType(tree[1])}[]";
      } else {
        return "any[]";
      }
    }
    
    return tree[0];
  }
  
  String _handleParams(List<Parameter> parameters) =>
    parameters
      .map((Parameter param) {
        var suffix = param.kind == ParameterKind.POSITIONAL ? "?" : "";      
        
        return "${param.name}$suffix: ${_handleType(param.type)}";
      })
      .join(", ");
  
  String _makeFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType,
      [String subName]) {
    var name = subName != null ? subName : data["name"];
    
    returnType = _handleType(returnType);
    var paramStr = _handleParams(parameters);
    
    return "$name($paramStr): $returnType;";
  }
  
  addTopLevelFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType) {   
    final str = _makeFunction(data, parameters, returnType); 
    _buffer.writeln("\tfunction $str");
  }
  
  startClass(Map<String, dynamic> data) {
    _classBuffer = new _DualStringBuffer();
    _className = data["name"];
    
    _classBuffer.writeln("\tclass ${data["name"]} {");
  }
  
  stopClass() {
    _classBuffer.writeln("\t}");
    
    _buffer.write("\n$_classBuffer");
    _classBuffer = null;
  }
  
  addClassConstructor(Map<String, dynamic> data, List<Parameter> parameters) {
    _classBuffer.writeln("\t\tconstructor(${_handleParams(parameters)});");
  }
  
  addClassStaticFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType) {
    var name = data["name"].contains(_className + ".") ?
      (data["name"] as String).substring(_className.length + 1) :
      data["name"];
    final str = _makeFunction(data, parameters, returnType, name); 
    _classBuffer.writeln("\t\tstatic $str");
  }
  
  addClassFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType) {
    final str = _makeFunction(data, parameters, returnType); 
    _classBuffer.writeln("\t\t$str");
  }
  
  addClassStaticMember(Map<String, dynamic> data) {
    final name = data["name"];
    final type = data["type"];
    
    _classBuffer.writeln("\t\tstatic $name: ${_handleType(type)};");
  }
  
  addClassMember(Map<String, dynamic> data) {
    final name = data["name"];
    final type = data["type"];
    
    _classBuffer.writeln("\t\t$name: ${_handleType(type)};");
  }
}