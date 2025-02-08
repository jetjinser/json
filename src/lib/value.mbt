///|
enum Value {
  Continue(ContinueValue)
  Finish(FinishValue)
}

///|
struct ContinueValue {
  rest : ArrayView[Char]
  arr_acc : JsonArray
  obj_acc : JsonObject
  stack : Array[Stack]
  decode : &Decode
  func_data : FuncData
}

///|
struct FinishValue {
  value : Json
  arr_acc : JsonArray
  obj_acc : JsonObject
  rest : ArrayView[Char]
} derive(Show)

///|
enum FuncData {
  Value
  Number(Int)
  Key
  ArrayPush(Json)
  ObjectValue(String)
  ObjectPush((Json, String))
} derive(Show)
