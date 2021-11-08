open GRPC

let server = Server.create ~listening:"unix:socket" ()

let () =
  let c = Server.wait_call ~timeout:5L server in
  print_endline "wait_call succeeded";
  List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) c.metadatas;
  let open (val Call.o c.call) in
  let> () = send_initial_metadata [ ("caml-grcp", "bye") ]
  and> msg = recv_message ()
  and> () = timeout 5L in
  print_endline "wait_call 2 succeeded";
  Printf.printf "msg: %s\n" msg;
  let> () = send_message "Yes, I feel very connected"
  and> cancelled = recv_close_on_server ()
  and> () = timeout 5L in
  print_endline "wait_call 3 succeeded";
  Printf.printf "cancelled: %b" cancelled

let () = Server.destroy server
