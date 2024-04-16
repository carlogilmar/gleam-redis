import gleam/io

import gleam/bytes_builder
import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}

pub fn main() {
  io.println(" Aquí ANDAMOS PERRO")

   let assert Ok(_redis_conn) = // assert successful connection
     glisten.handler(
        fn(_conn) { #(Nil, None) }, // fun to handle incoming connections
        fn(msg, state, conn) { //fun to handle messages
          io.debug(msg)
          let assert Packet(_msg) = msg
          let assert Ok(_) = glisten.send(conn, bytes_builder.from_string("+PONG\r\n"))
          actor.continue(state)
     })
     |> glisten.serve(6379) // Uses the handler to start a server

  process.sleep_forever()
}
