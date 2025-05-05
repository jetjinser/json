///|
pub type! ParseError Reason derive(Show)

///|
pub enum Reason {
  InvalidByte(Int, Char)
  UnexpectedEnd(Checkpoint)
  UnexpectedSequence(Array[Char], Int)
} derive(Show)
