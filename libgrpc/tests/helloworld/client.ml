open GRPC

let client = Client.create ~target:"unix:socket" ()

let () =
  let call = Client.call ~meth:"hello" client in
  let metadatas = ref [] in
  Call.send_ops ~timeout:4L call
    [
      Ops.SEND_INITIAL_METADATA [ ("caml-grcp", "hello") ];
      Ops.RECV_INITIAL_METADATA metadatas;
      Ops.SEND_MESSAGE "Are you happy?";
    ];
  print_endline "wait_call succeeded";
  List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) !metadatas;
  let msg = ref "" in
  Call.send_ops ~timeout:4L call
    [ Ops.RECV_MESSAGE msg; Ops.SEND_CLOSE_FROM_CLIENT ];
  print_endline "wait_call 2 succeeded";
  Printf.printf "msg: %s\n" !msg

let () = Client.destroy client
