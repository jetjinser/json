// TODO:
// - reasonable Error
// - inplace mutable for some attributes

///|
type! InvalidByte (Int, Char) derive(Show)

///|
struct Context {
  original : Array[Char]
  rest : ArrayView[Char]
  skip : Int
  arr_acc : Array[Json]
  obj_acc : Map[String, Json]
  stack : Array[Stack]
  decode : &Decode
}

///|
enum Stack {
  Array(Array[Json])
  Map(Map[String, Json])
  Key(String)
} derive(Show)

///|
fn decode!(input : String, decode? : &Decode) -> Json {
  let decode = match decode {
    Some(decode) => decode
    None => ()
  }
  let ctx = Context::{
    rest: input.to_array()[:],
    original: input.to_array(),
    skip: 0,
    arr_acc: [],
    obj_acc: Map::new(),
    stack: [],
    decode,
  }
  match value!(ctx) {
    Finish({ value, rest: [], .. }) => value
    Finish({ rest, .. }) => raise invalid_byte([..rest], 0)
    Continue({ func_data: FuncData::NumberI(n), .. }) => n.to_json()
    Continue({ func_data: FuncData::NumberD(n), .. }) => n.to_json()
    Continue({ func_data, .. }) => {
      println("unexpected end: \{func_data}")
      // TODO: unexpected_end error
      raise invalid_byte([], 0)
    }
  }
}

///|
fn decode_start!(input : String, decode? : &Decode) -> Value {
  let decode = match decode {
    Some(decode) => decode
    None => ()
  }
  let ctx = Context::{
    rest: input.to_array()[:],
    original: input.to_array(),
    skip: 0,
    arr_acc: [],
    obj_acc: Map::new(),
    stack: [],
    decode,
  }
  value!(ctx)
}

///|
fn decode_continue!(cont : String, state : ContinueValue) -> Value {
  let input = [..state.rest, ..cont.to_array()]
  let ctx = Context::{
    rest: input[:],
    original: input,
    skip: 0,
    arr_acc: state.arr_acc,
    obj_acc: state.obj_acc,
    stack: state.stack,
    decode: state.decode,
  }
  match state.func_data {
    Value | NumberI(_) | NumberD(_) => value!(ctx)
    ArrayPush(v) => array_push!(ctx, v)
    ObjectValue(key) => object_value!(ctx, key)
    ObjectPush((value, key)) => object_push!(ctx, value, key)
    Key => object_key!(ctx)
    FloatError(_token, _skip) => value!(ctx)
  }
}

///|
fn value!(ctx : Context) -> Value {
  match ctx.rest {
    // skip whitespace
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      value!({ ..ctx, rest, skip: ctx.skip + 1 })
    ['0', .. rest] => number_zero!({ ..ctx, rest, }, 1)
    ['1'..='9', .. rest] => number!({ ..ctx, rest, }, 1)
    ['-', .. rest] => number_minus!({ ..ctx, rest, })
    ['t', .. rest] => true_!({ ..ctx, rest, })
    ['f', .. rest] => false_!({ ..ctx, rest, })
    ['n', .. rest] => null!({ ..ctx, rest, })
    ['"', .. rest] => string!({ ..ctx, rest, skip: ctx.skip + 1 }, 0)
    ['[', .. rest] => array_start!({ ..ctx, rest, }, 1)
    ['{', .. rest] => object_start!({ ..ctx, rest, }, 1)
    _ => unexpected!(ctx, 0, 0, FuncData::Value)
  }
}

// number {{{

///|
fn number_zero!(ctx : Context, len : Int) -> Value {
  match ctx.rest {
    [] => {
      let value = ctx.decode.integer!(['0'][:])
      unexpected!(ctx, len, 0, FuncData::NumberI(value))
    }
    rest => {
      let value = ctx.decode.integer!(['0'][:])
      continue_!(
        { ..ctx, rest, skip: ctx.skip + len },
        Json::number(value.to_double()),
      )
    }
  }
}

///|
fn number!(ctx : Context, len : Int) -> Value {
  let { original, skip, .. } = ctx
  match ctx.rest {
    ['0'..='9', .. rest] => number!({ ..ctx, rest, }, len + 1)
    ['.', .. rest] => number_frac!({ ..ctx, rest, }, len + 1)
    ['e' | 'E', .. rest] => {
      let prefix = original[skip:skip + len]
      number_exp_copy!({ ..ctx, rest, }, len + 1, prefix)
    }
    [] => {
      let part = original[skip:skip + len]
      let value = ctx.decode.integer!(part)
      unexpected!(ctx, len, 0, FuncData::NumberI(value))
    }
    rest => {
      let part = original[skip:skip + len]
      let value = ctx.decode.integer!(part)
      continue_!(
        { ..ctx, rest, skip: skip + len },
        Json::number(value.to_double()),
      )
    }
  }
}

///|
fn number_frac!(ctx : Context, len : Int) -> Value {
  match ctx.rest {
    ['0'..='9', .. rest] => number_frac_cont!({ ..ctx, rest, }, len + 1)
    _ => unexpected!(ctx, len, 0, FuncData::Value)
  }
}

///|
fn number_frac_cont!(ctx : Context, len : Int) -> Value {
  let { original, skip, .. } = ctx
  match ctx.rest {
    ['0'..='9', .. rest] => number_frac_cont!({ ..ctx, rest, }, len + 1)
    ['e' | 'E', .. rest] => number_exp!({ ..ctx, rest, }, len + 1)
    _ => {
      let token = original[skip:skip + len]
      float_decode!(ctx, len, token)
    }
  }
}

///|
fn float_decode!(ctx : Context, len : Int, token : ArrayView[Char]) -> Value {
  let { skip, .. } = ctx
  match ctx.rest {
    [] =>
      match ctx.decode.double?(token) {
        Ok(value) => unexpected!(ctx, len, 0, FuncData::NumberD(value))
        Err(_) => unexpected!(ctx, len, 0, FuncData::FloatError(token, skip))
      }
    rest =>
      match ctx.decode.double?(token) {
        Ok(value) =>
          continue_!({ ..ctx, rest, skip: skip + len }, value.to_json())
        Err(_) =>
          unexpected!(ctx, len, 0, FuncData::FloatError(token, ctx.skip))
      }
  }
}

///|
fn number_exp!(ctx : Context, len : Int) -> Value {
  match ctx.rest {
    ['0'..='9', .. rest] => number_exp_cont!({ ..ctx, rest, }, len + 1)
    ['+' | '-', .. rest] => number_exp_sign!({ ..ctx, rest, }, len + 1)
    _ => unexpected!(ctx, len, 0, FuncData::Value)
  }
}

///|
fn number_exp_sign!(ctx : Context, len : Int) -> Value {
  match ctx.rest {
    ['0'..='9', .. rest] => number_exp_sign!({ ..ctx, rest, }, len + 1)
    _ => unexpected!(ctx, len, 0, FuncData::Value)
  }
}

///|
fn number_exp_cont!(ctx : Context, len : Int) -> Value {
  let { original, skip, .. } = ctx
  match ctx.rest {
    ['0'..='9', .. rest] => number_exp_cont!({ ..ctx, rest, }, len + 1)
    _ => {
      let token = original[skip:skip + len]
      float_decode!(ctx, len, token)
    }
  }
}

///|
fn number_exp_copy!(
  ctx : Context,
  len : Int,
  prefix : ArrayView[Char]
) -> Value {
  match ctx.rest {
    ['0'..='9', .. rest] =>
      number_exp_cont_with_prefix!({ ..ctx, rest, }, len, prefix, 1)
    ['+' | '-', .. rest] =>
      number_exp_sign_with_prefix!({ ..ctx, rest, }, len, prefix, 1)
    _ => unexpected!(ctx, len, 0, FuncData::Value)
  }
}

///|
fn number_exp_sign_with_prefix!(
  ctx : Context,
  len : Int,
  prefix : ArrayView[Char],
  exp_len : Int
) -> Value {
  match ctx.rest {
    ['0'..='9', .. rest] =>
      number_exp_cont_with_prefix!({ ..ctx, rest, }, len, prefix, exp_len + 1)
    _ => unexpected!(ctx, len + exp_len, 0, FuncData::Value)
  }
}

///|
fn number_exp_cont_with_prefix!(
  ctx : Context,
  len : Int,
  prefix : ArrayView[Char],
  exp_len : Int
) -> Value {
  let { original, skip, .. } = ctx
  match ctx.rest {
    ['0'..='9', .. rest] =>
      number_exp_cont_with_prefix!({ ..ctx, rest, }, len, prefix, exp_len + 1)
    _ => {
      let suffix = original[skip:skip + len]
      let token = [..prefix, '.', '0', 'e', ..suffix]
      float_decode!(ctx, len + exp_len, token)
    }
  }
}

///|
fn number_minus!(ctx : Context) -> Value {
  match ctx.rest {
    ['0', .. rest] => number_zero!({ ..ctx, rest, }, 2)
    ['0'..='9', .. rest] => number!({ ..ctx, rest, }, 2)
    _ => unexpected!(ctx, 1, 0, FuncData::Value)
  }
}

// }}}

// constants {{{

///|
fn true_!(ctx : Context) -> Value {
  match ctx.rest {
    ['r', 'u', 'e', .. rest] =>
      continue_!({ ..ctx, rest, skip: ctx.skip + 4 }, Json::boolean(true))
    _ => unexpected!(ctx, 1, 3, FuncData::Value)
  }
}

///|
fn false_!(ctx : Context) -> Value {
  match ctx.rest {
    ['a', 'l', 's', 'e', .. rest] =>
      continue_!({ ..ctx, rest, skip: ctx.skip + 5 }, Json::boolean(false))
    _ => unexpected!(ctx, 1, 4, FuncData::Value)
  }
}

///|
fn null!(ctx : Context) -> Value {
  match ctx.rest {
    ['u', 'l', 'l', .. rest] =>
      continue_!({ ..ctx, rest, skip: ctx.skip + 4 }, Json::null())
    _ => unexpected!(ctx, 1, 3, FuncData::Value)
  }
}

// }}}

// string {{{

///|
fn string!(ctx : Context, len : Int) -> Value {
  let { original, skip, .. } = ctx
  match ctx.rest {
    ['"', .. rest] => {
      let value = original[skip:skip + len]
      let skip = skip + len + 1
      let s = ctx.decode.string(String::from_iter(value.iter()))
      continue_!({ ..ctx, rest, skip }, Json::string(s))
    }
    [_, .. rest] => string!({ ..ctx, rest, }, len + 1)
    _ => unexpected!({ ..ctx, skip: skip - 1 }, len + 1, 0, FuncData::Value)
  }
}

// }}}

// array {{{

///|
fn array_start!(ctx : Context, len : Int) -> Value {
  let { decode, skip, arr_acc, .. } = ctx
  match ctx.rest {
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      array_start!({ ..ctx, rest, }, len + 1)
    [']', .. rest] => {
      let (value, new_acc) = ctx.decode.array_finish(
        ctx.decode.array_start(arr_acc),
        arr_acc,
      )
      continue_!(
        { ..ctx, rest, skip: skip + len + 1, arr_acc: new_acc },
        Json::array(value),
      )
    }
    [] => unexpected!(ctx, len, 0, FuncData::Value)
    rest => {
      let new_acc = decode.array_start(arr_acc)
      ctx.stack.push(Stack::Array(arr_acc))
      value!({ ..ctx, rest, skip: skip + len, arr_acc: new_acc })
    }
  }
}

///|
fn array_push!(ctx : Context, value0 : Json) -> Value {
  let { skip, .. } = ctx
  match ctx.rest {
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      array_push!({ ..ctx, rest, skip: skip + 1 }, value0)
    [']', .. rest] => {
      let acc = ctx.decode.array_push(value0, ctx.arr_acc)
      guard ctx.stack.pop() is Some(Stack::Array(old_acc))
      let (array_value, new_acc) = ctx.decode.array_finish(acc, old_acc)
      continue_!(
        { ..ctx, rest, skip: skip + 1, arr_acc: new_acc },
        Json::array(array_value),
      )
    }
    [',', .. rest] => {
      let arr_acc = ctx.decode.array_push(value0, ctx.arr_acc)
      value!({ ..ctx, rest, skip: skip + 1, arr_acc })
    }
    _ => unexpected!(ctx, 0, 0, FuncData::ArrayPush(value0))
  }
}

// }}}

// object {{{

///|
fn object_start!(ctx : Context, len : Int) -> Value {
  let { obj_acc, skip, .. } = ctx
  match ctx.rest {
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      object_start!({ ..ctx, rest, }, len + 1)
    ['}', .. rest] => {
      let (value, new_acc) = ctx.decode.object_finish(
        ctx.decode.object_start(obj_acc),
        obj_acc,
      )
      continue_!(
        { ..ctx, rest, skip: skip + len + 1, obj_acc: new_acc },
        Json::object(value),
      )
    }
    ['"', .. rest] => {
      ctx.stack.push(Stack::Map(obj_acc))
      string!(
        {
          ..ctx,
          rest,
          skip: skip + len + 1,
          obj_acc: ctx.decode.object_start(obj_acc),
        },
        0,
      )
    }
    _ => unexpected!(ctx, len, 0, FuncData::Value)
  }
}

///|
fn object_value!(ctx : Context, key : String) -> Value {
  let { skip, .. } = ctx
  match ctx.rest {
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      object_value!({ ..ctx, rest, skip: skip + 1 }, key)
    [':', .. rest] => {
      ctx.stack.push(Stack::Key(key))
      value!({ ..ctx, rest, skip: skip + 1 })
    }
    _ => unexpected!(ctx, 0, 0, FuncData::ObjectValue(key))
  }
}

///|
fn object_push!(ctx : Context, value0 : Json, key : String) -> Value {
  let { skip, .. } = ctx
  match ctx.rest {
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      object_push!({ ..ctx, rest, skip: skip + 1 }, value0, key)
    ['}', .. rest] => {
      let acc = ctx.decode.object_push(key, value0, ctx.obj_acc)
      guard ctx.stack.pop() is Some(Stack::Map(old_acc))
      let (object_value, new_acc) = ctx.decode.object_finish(acc, old_acc)
      continue_!(
        { ..ctx, rest, skip: skip + 1, obj_acc: new_acc },
        Json::object(object_value),
      )
    }
    [',', .. rest] => {
      let obj_acc = ctx.decode.object_push(key, value0, ctx.obj_acc)
      object_key!({ ..ctx, rest, skip: skip + 1, obj_acc })
    }
    _ => unexpected!(ctx, 0, 0, FuncData::ObjectPush((value0, key)))
  }
}

///|
fn object_key!(ctx : Context) -> Value {
  let { skip, .. } = ctx
  match ctx.rest {
    ['\ ' | '\n' | '\r' | '\t', .. rest] =>
      object_key!({ ..ctx, rest, skip: skip + 1 })
    ['"', .. rest] => string!({ ..ctx, rest, skip: skip + 1 }, 0)
    _ => unexpected!(ctx, 0, 0, FuncData::Key)
  }
}

// }}}

///|
fn continue_(ctx : Context, value : Json) -> Value! {
  match ctx.stack.last() {
    None => terminate!(ctx, value)
    Some(Stack::Array(_)) => array_push!(ctx, value)
    Some(Stack::Map(_)) => object_value!(ctx, value.as_string().unwrap())
    Some(Stack::Key(key)) => {
      ctx.stack.pop() |> ignore
      object_push!({ ..ctx }, value, key)
    }
  }
}

///|
fn terminate(ctx : Context, value : Json) -> Value! {
  let { rest, original, skip, arr_acc, obj_acc, .. } = ctx
  match rest {
    // skip whitespace
    ['\ ' | '\n' | '\r' | '\t', .. rest] => terminate!({ ..ctx, rest, }, value)
    [] => Value::Finish({ value, arr_acc, obj_acc, rest: [][:] })
    _ => {
      let rest = original[skip:]
      Value::Finish({ value, arr_acc, obj_acc, rest })
    }
  }
}

///|
fn unexpected(
  ctx : Context,
  pos : Int,
  len : Int,
  func_data : FuncData
) -> Value! {
  let { original, arr_acc, obj_acc, skip, stack, decode, .. } = ctx
  let required_size = skip + pos + len
  let original_size = original.length()
  if original_size <= required_size {
    let rest = original[skip:]
    Value::Continue(ContinueValue::{
      rest,
      arr_acc,
      obj_acc,
      stack,
      decode,
      func_data,
    })
  } else {
    raise invalid_byte(ctx.original, ctx.skip + pos)
  }
}

///|
fn invalid_byte(arr : Array[Char], skip : Int) -> InvalidByte {
  let byte = arr[skip]
  InvalidByte((skip, byte))
}

/// ==== example ====

///|
struct CustomDecode {}

///|
impl Decode for CustomDecode with object_push(_self, key, value, acc) {
  match key {
    "foo" | "bar" => acc[key] = value
    _ => ()
  }
  acc
}

///|
impl Decode for CustomDecode with string(_self, s) {
  println("got string `\{s}`")
  s
}

///|
test "json" {
  let compelet_json =
    #|{"foo": {"bar": 1}, "quz": [42, true]}
  guard compelet_json.to_array().chunks(6).map(String::from_array)
    is [first_chunk, .. chunks]
  let value = decode_start!(first_chunk, decode=CustomDecode::{  })
  println("start parsing from `\{first_chunk}`")
  loop chunks, value {
    [chunk, .. chunks], Continue(state) => {
      println("continue parsing `\{chunk}`")
      continue chunks, decode_continue!(chunk, state)
    }
    [], Finish(v) => {
      println("parse finished")
      println(v.value.stringify(indent=2))
    }
    _, _ => raise InspectError("unreachable")
  }
}
