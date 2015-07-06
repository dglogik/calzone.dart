var json = {};

function assert(bool) {
  if(!bool)
    throw new Error("assert failed");
}

function describe(id, cb) {
  try {
    cb();
    json[id] = true;
  } catch(e) {
    json[id] = false;
  }
}

console.log(JSON.stringify(json));
