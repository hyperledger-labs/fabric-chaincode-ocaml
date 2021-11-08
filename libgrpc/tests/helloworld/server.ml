open GRPC

let server = Server.create ~listening:"unix:socket" ()

let () =
  match Server.wait_call ~timeout:5L server with
  | TIMEOUT -> print_endline "wait_call timeout"
  | CALL c -> (
      print_endline "wait_call succeeded";
      List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) c.metadatas;
      let rmsg = ref "" in
      match
        Call.send_ops ?timeout:(Some 5L) c.call
          [
            Ops.SEND_INITIAL_METADATA [ ("caml-grcp", "bye") ];
            Ops.RECV_MESSAGE rmsg;
          ]
      with
      | Call.TIMEOUT -> print_endline "wait_call 2 timeout"
      | Call.OK ->
          print_endline "wait_call 2 succeeded";
          Printf.printf "msg: %s" !rmsg)

let () = Server.destroy server
