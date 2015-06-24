function objEach(obj, cb, thisArg) {
  if(typeof thisArg !== 'undefined') {
    cb = cb.bind(thisArg);
  }

  var count = 0;
  var keys = Object.keys(obj);
  var length = keys.length;

  for(; count < length; count++) {
    var key = keys[count];
    cb(obj[key], key, obj);
  }
}

var map = {
  libraries: {}
};

init.libraries.forEach(function(elm) {
  var library = {
    names: {}
  };

  elm.forEach(function(elm, index) {
    if(index == 0) {
      library.name = elm;
    }

    if(Array.isArray(elm)) {
      elm.forEach(function(name) {
        library.names[init.mangledGlobalNames[name]] = name;
      });
    }
  });

  map.libraries[library.name] = library;
});

console.log(JSON.stringify(map));
