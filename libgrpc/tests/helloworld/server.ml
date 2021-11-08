open GRPC

let server = Server.create ~listening:"unix:socket" ()

let () =
  let c = Server.wait_call ~timeout:5L server in
  print_endline "wait_call succeeded";
  Printf.printf "method:%s\nhost:%s\n" c.method_ c.host;
  List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) c.metadatas;
  let open (val Call.o c.call) in
  let> () = send_initial_metadata [ ("caml-grcp", "bye") ]
  and> msg = recv_message ()
  and> () = timeout 5L in
  print_endline "wait_call 2 succeeded";
  Printf.printf "msg: %s\n" msg;
  let> () = send_message "Yes, I feel very connected"
  and> () = send_status_from_server GRPC_STATUS_OK
  and> () = timeout 5L in
  print_endline "wait_call 3 succeeded"

let () = Server.destroy server
