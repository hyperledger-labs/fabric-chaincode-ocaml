open GRPC

let server = Server.create ~listening:"localhost:50052" ()

let () =
  match Server.wait_call ~timeout:5L server with
  | TIMEOUT -> print_endline "wait_call timeout"
  | CALL c -> (
      print_endline "wait_call succeeded";
      List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) c.metadatas;
      match
        Call.send_ops ?timeout:(Some 5L) c.call
          [ Ops.SEND_INITIAL_METADATA [ ("caml-grcp", "bye") ] ]
      with
      | Call.TIMEOUT -> print_endline "wait_call 2 timeout"
      | Call.OK -> print_endline "wait_call 2 succeeded")

let () = Server.destroy server
