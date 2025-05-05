///|
pub traitalias @lib.Decode

///|
pub fnalias @lib.(decode, decode_start, decode_continue)

///|
pub typealias @lib.Value

///|
test "json" {
  let compelet_json =
    #|{"foo": {"bar": 1.2e3}, "quz": [42, true]}
  guard compelet_json.to_array().chunks(6).map(String::from_array)
    is [first_chunk, .. chunks]
  let value = decode_start!(first_chunk)
  //println("start parsing from `\{first_chunk}`")
  loop chunks, value {
    [chunk, .. chunks], Continue(state) =>
      //println("continue parsing `\{chunk}`")
      continue chunks, decode_continue!(chunk, state)
    [], Finish(v) =>
      //println("parse finished")
      println(v.value.stringify(indent=2))
    _, _ => raise InspectError("unreachable")
  }
}
