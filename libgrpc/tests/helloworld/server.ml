open GRPC

let server = Server.create ~listening:"unix:socket" ()

let () =
  let c = Server.wait_call ~timeout:5L server in
  print_endline "wait_call succeeded";
  List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) c.metadatas;
  let rmsg = ref "" in
  Call.send_ops ?timeout:(Some 5L) c.call
    [
      Ops.SEND_INITIAL_METADATA [ ("caml-grcp", "bye") ]; Ops.RECV_MESSAGE rmsg;
    ];
  print_endline "wait_call 2 succeeded";
  Printf.printf "msg: %s\n" !rmsg;
  let cancelled = ref false in
  Call.send_ops ?timeout:(Some 5L) c.call
    [
      Ops.SEND_MESSAGE "Yes, I feel very connected";
      Ops.RECV_CLOSE_ON_SERVER { cancelled };
    ];
  print_endline "wait_call 3 succeeded";
  Printf.printf "cancelled: %b" !cancelled

let () = Server.destroy server
