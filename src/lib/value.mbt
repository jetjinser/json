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
  NumberI(Int)
  NumberD(Double)
  Key
  ArrayPush(Json)
  ObjectValue(String)
  ObjectPush((Json, String))
  FloatError(ArrayView[Char], Int)
} derive(Show)
