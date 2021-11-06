open GRPC

module Core = struct
  open Core

  let () =
    let slice = slice_of_string "Test" in
    print_endline @@ string_of_slice slice

  let () = print_endline (grpc_version_string ())

  let () = print_endline (grpc_g_stands_for ())
end

let server = create_server ~listening:"localhost:30300" ()

let () =
  match wait_call ~timeout:2L server with
  | TIMEOUT -> print_endline "wait_call timeout"
  | CALL _ -> print_endline "wait_call succeeded"

let () = destroy_server server
