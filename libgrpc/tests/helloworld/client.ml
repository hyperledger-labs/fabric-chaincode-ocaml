open GRPC

let client = Client.create ~target:"unix:socket" ()

let () =
  let call = Client.call ~meth:"hello" client in
  let open (val Call.o call) in
  let> () = send_initial_metadata [ ("caml-grcp", "hello") ]
  and> metadatas = recv_initial_metadata ()
  and> () = send_message "Are you happy?"
  and> () = timeout 4L in
  print_endline "wait_call succeeded";
  List.iter (fun (k, v) -> Printf.printf "%s:%s\n" k v) metadatas;
  let> msg = recv_message ()
  and> close = recv_status_on_client ()
  and> () = timeout 4L in
  print_endline "wait_call 2 succeeded";
  Printf.printf "msg: %s\n" msg;
  Printf.printf "status: %s\n" (Op.show_status_code close.status)

let () = Client.destroy client
