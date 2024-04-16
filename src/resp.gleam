import gleam/int
import gleam/result
import gleam/string
import gleam/list


pub type RESP {
  SimpleString(String)
  BulkString(String)
  SimpleError(String)
  Array(List(RESP))
  Null
  }

type ParserResult =
  Result(#(RESP, String), String)

const crlf = "\r\n"

pub fn encode(resp: RESP) -> String {
  case resp {
    SimpleString(s) -> "+" <> s <> crlf
    BulkString(s) -> "$" <> int.to_string(string.length(s)) <> crlf <> s <> crlf
    SimpleError(s) -> "-" <> s <> crlf
    Array(resps) ->
      "*"
      <> int.to_string(list.length(resps))
      <> crlf
      <> resps
      |> list.map(encode)
      |> string.join(with: "")
    Null -> "_" <> crlf
  }
}

pub fn decode(input: String) -> Result(#(RESP, String), RESP) {
  case parse(input) {
    Ok(resp) -> Ok(resp)
    Error(s) -> Error(SimpleError("ERR " <> s))
  }
}

fn parse(input: String) -> Result(#(RESP, String), String) {
  case string.pop_grapheme(input) {
    Ok(#("+", rest)) -> parse_simple_string(rest)
    Ok(#("$", rest)) -> parse_bulk_string(rest)
    Ok(#("*", rest)) -> parse_array(rest)
    Ok(#("_", rest)) -> parse_null(rest)
    Ok(#(c, _)) -> Error("Unknown RESP type '" <> c <> "'")
    Error(Nil) -> Error("Empty input")
  }
}

fn parse_simple_string(input: String) -> ParserResult {
  case string.split_once(input, on: crlf) {
    Ok(#(s, rest)) -> Ok(#(SimpleString(s), rest))
    Error(Nil) -> Error("SimpleString end token not found")
  }
}

fn split_len(input) {
  string.split_once(input, on: crlf)
  |> result.replace_error("length separator not found")
}

fn parse_int(input) {
  int.parse(input)
  |> result.replace_error("failed to parse integer from " <> input)
}

fn parse_bulk_string(input: String) -> ParserResult {
  use #(len, s) <- result.try(split_len(input))
  use len <- result.try(parse_int(len))
  let rest = string.slice(s, at_index: len, length: string.length(s))
  let s = string.slice(s, at_index: 0, length: len)
  let end_crlf = string.first(rest)
  let rest = string.drop_left(rest, 1)
  case #(string.length(s) == len, end_crlf == Ok(crlf)) {
    #(True, True) ->
      Ok(#(BulkString(string.slice(s, at_index: 0, length: len)), rest))
    #(False, _) -> Error("BulkString length does not match content")
    #(_, False) -> Error("BulkString does not end with crlf")
  }
}

fn parse_array(input: String) -> ParserResult {
  use #(len, s) <- result.try(split_len(input))
  use len <- result.try(parse_int(len))
  use #(array, rest) <- result.try(parse_array_rec(s, len, []))
  Ok(#(Array(array), rest))
}

fn parse_array_rec(input, n, acc) {
  case n {
    n if n < 0 -> Error("Array has negative length")
    0 -> Ok(#(list.reverse(acc), input))
    n -> {
      use #(resp, rest) <- result.try(parse(input))
      parse_array_rec(rest, n - 1, [resp, ..acc])
    }
  }
}

fn parse_null(input) -> ParserResult {
  case string.first(input) {
    Ok(c) if c == crlf -> Ok(#(Null, string.drop_left(input, 1)))
    _ -> Error("Null not terminated by crlf")
  }
}
