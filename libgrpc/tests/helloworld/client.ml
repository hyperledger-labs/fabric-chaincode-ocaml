open GRPC

let client = Client.create ~target:"localhost:50052" ()

let () =
  let call = Client.call ~meth:"hello" client in
  let metadatas = ref [] in
  match
    Call.send_ops ~timeout:4L call
      [
        Ops.SEND_INITIAL_METADATA [ ("caml-grcp", "hello") ];
        Ops.RECV_INITIAL_METADATA metadatas;
      ]
  with
  | TIMEOUT -> print_endline "wait_call timeout"
  | OK ->
      print_endline "wait_call succeeded";
      List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) !metadatas

let () = Client.destroy client
