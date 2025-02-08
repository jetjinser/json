///|
typealias JsonArray = Array[Json]

///|
typealias JsonObject = Map[String, Json]

///|
trait Decode {
  array_start(Self, JsonArray) -> JsonArray
  array_push(Self, Json, JsonArray) -> JsonArray
  array_finish(Self, JsonArray, JsonArray) -> (JsonArray, JsonArray)
  object_start(Self, JsonObject) -> JsonObject
  object_push(Self, String, Json, JsonObject) -> JsonObject
  object_finish(Self, JsonObject, JsonObject) -> (JsonObject, JsonObject)
  double(Self, ArrayView[Char]) -> Double!
  integer(Self, ArrayView[Char]) -> Int!
  string(Self, String) -> String
}

///|
impl Decode with array_start!(_self, _old_acc) { [] }

///|
impl Decode with array_push!(_self, elem, acc) { [elem, ..acc] }

///|
impl Decode with array_finish!(_self, acc, old_acc) { (acc.rev(), old_acc) }

///|
impl Decode with object_start!(_self, _old_acc) { {} }

///|
impl Decode with object_push!(_self, key, value, acc) {
  acc[key] = value
  acc
}

///|
impl Decode with object_finish!(_self, acc, old_acc) { (acc, old_acc) }

///|
impl Decode with double!(_self, view) {
  @strconv.parse_double!(@string.from_iter(view.iter()).to_string())
}

///|
impl Decode with integer!(_self, view) {
  @strconv.parse_int!(@string.from_iter(view.iter()).to_string())
}

///|
impl Decode with string!(_self, s) { s }
