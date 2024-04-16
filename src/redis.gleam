import gleam/io

import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import gleam/bit_array
import gleam/result
import gleam/string
import gleam/dict
import resp

pub fn main() {
  io.println(" Aquí ANDAMOS PERRO")

   let assert Ok(_redis_conn) = // assert successful connection
     glisten.handler(
        fn(_conn) { #(dict.new(), None) }, // fun to handle incoming connections
        fn(msg, state, conn) { //fun to handle messages
          io.debug(msg)
          let assert Packet(msg) = msg // 1. Assert msg Packet type
          let #(response, new_state) = handle_message(msg, state) // 2. Validate msg and return the response
          let assert Ok(_) = glisten.send(conn, response) // 3. Serve the response
					io.debug(new_state)
          actor.continue(new_state)
     })
     |> glisten.serve(6379) // Uses the handler to start a server

  process.sleep_forever()
}

//4. Main function to valid the msg from TCP connections
fn handle_message(msg, state){
	let #(response, new_state) =
    msg
    |> bit_array.to_string()
    |> result.replace_error(resp.SimpleError("ERROR Invalid command HEHE"))
    |> result.try( fn(cmd) { handle_cmd(cmd, state) })
	  |> result.map_error(fn(e) {#(e, state)})
    |> result.unwrap_both()

	let response =
    response
    |> resp.encode()
    |> bytes_builder.from_string()

	#(response, new_state)
}

// 5. This function evaluates if the command is PING or ECHO
fn handle_cmd(cmd, state) -> Result(#(resp.RESP, dict.Dict(String, String)), resp.RESP){

  use #(cmd, _rest) <- result.try(resp.decode(cmd))

  use #(cmd, args) <- result.try(case cmd {
      resp.Array([resp.BulkString(cmd), ..args]) -> Ok(#(cmd, args))
      _ -> Error(resp.SimpleError("Error Invalid Command"))
    })

  case string.lowercase(cmd) {
      "ping" ->
				handle_ping(args)
				|> with_unchanged_state(state)
      "echo" ->
				handle_echo(args)
				|> with_unchanged_state(state)
			"set" ->
				handle_set(args, state)
			"get" ->
				handle_get(args, state)
				|> with_unchanged_state(state)
      unknown_cmd ->
				Error(resp.SimpleError("ERR unknown command" <> unknown_cmd))
    }
}

fn with_unchanged_state(r, state) {
  result.map(r, fn(r) { #(r, state) })
}

fn handle_ping(args) {
  case args {
    [] -> Ok(resp.SimpleString("PONG"))
    [resp.BulkString(_) as arg] -> Ok(arg)
    _unknown -> Error(resp.SimpleError("ERR invalid for ping"))
    }
  }

fn handle_echo(args) {
  case args {
    [resp.BulkString(_) as arg] -> Ok(arg)
    _unknown -> Error(resp.SimpleError("ERR invalid for echo"))
    }
  }

fn handle_set(args, state) {
  case args {
    [resp.BulkString(key), resp.BulkString(value)] -> {
      let new_state = dict.insert(state, key, value)
			io.debug(new_state)
      Ok(#(resp.SimpleString("OK"), new_state))
    }
    _ -> Error(resp.SimpleError("ERR Invalid args for SET"))
  }
}

fn handle_get(args, state) {
  case args {
    [resp.BulkString(key)] ->
      case dict.get(state, key) {
        Ok(value) -> Ok(resp.BulkString(value))
        _ -> Ok(resp.Null)
      }
    _ -> Error(resp.SimpleError("Err Invalid args for GET"))
  }
}
