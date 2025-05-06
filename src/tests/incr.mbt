///|
test "incr json" {
  let compelet_json =
    #|{"foo": {"bar": 1.2e3}, "quz": [42, true]}
  guard compelet_json.to_array().chunks(6).map(String::from_array)
    is [first_chunk, .. chunks]
  let value = decode_start!(first_chunk)
  // start parsing from `first_chunk`
  loop chunks, value {
    [chunk, .. chunks], Continue(state) =>
      // continue parsing `chunk`
      continue chunks, decode_continue!(chunk, state)
    [], Finish({ value, .. }) => {
      // parse finished
      let expected = Object({
        "foo": Object({ "bar": Number(1200) }),
        "quz": Array([Number(42), True]),
      })
      assert_eq!(value, expected)
    }
    _, _ => raise InspectError("unreachable")
  }
}
