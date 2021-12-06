open GRPC

module Core = struct
  open Core

  let () =
    let slice = slice_of_string "Test" in
    print_endline @@ string_of_slice slice

  let () = print_endline (grpc_version_string ())

  let () = print_endline (grpc_g_stands_for ())
end

let server = Server.create ~listening:"unix:init_socket" ()

let () =
  match Server.wait_call ~timeout:0L server with
  | exception TIMEOUT -> print_endline "wait_call timeout"
  | _ -> print_endline "wait_call succeeded"

let () = Server.destroy server
