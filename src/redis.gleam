import gleam/io

import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import gleam/bit_array
import gleam/result
import gleam/string
import resp

pub fn main() {
  io.println(" Aquí ANDAMOS PERRO")

   let assert Ok(_redis_conn) = // assert successful connection
     glisten.handler(
        fn(_conn) { #(Nil, None) }, // fun to handle incoming connections
        fn(msg, state, conn) { //fun to handle messages
          io.debug(msg)
          let assert Packet(msg) = msg // 1. Assert msg Packet type
          let response = handle_message(msg) // 2. Validate msg and return the response
          let assert Ok(_) = glisten.send(conn, response) // 3. Serve the response
          actor.continue(state)
     })
     |> glisten.serve(6379) // Uses the handler to start a server

  process.sleep_forever()
}

//4. Main function to valid the msg from TCP connections
fn handle_message(msg){
  msg
  |> bit_array.to_string()
  |> result.replace_error(resp.SimpleError("ERROR Invalid command HEHE"))
  |> result.try(handle_cmd)
  |> result.unwrap_both()
  |> resp.encode()
  |> bytes_builder.from_string()
}

// 5. This function evaluates if the command is PING or ECHO
fn handle_cmd(cmd) -> Result(resp.RESP, resp.RESP){

  use #(cmd, _rest) <- result.try(resp.decode(cmd))

  use #(cmd, args) <- result.try(case cmd {
      resp.Array([resp.BulkString(cmd), ..args]) -> Ok(#(cmd, args))
      _ -> Error(resp.SimpleError("Error Invalid Command"))
    })

  case string.lowercase(cmd) {
      "ping" -> handle_ping(args)
      "echo" -> handle_echo(args)
      unknown_cmd -> Error(resp.SimpleError("ERR unknown command" <> unknown_cmd))
    }

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

