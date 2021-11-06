open Core
open Ctypes

type server = {
  server : grpc_server structure ptr;
  cq : grpc_completion_queue structure ptr;
  port : int;
}

let () = grpc_init ()

let () = at_exit (fun () -> grpc_shutdown ())

let create_server ~listening () =
  let server = grpc_server_create None null in
  let cq = grpc_completion_queue_create_for_pluck null in
  grpc_server_register_completion_queue server cq null;
  let port = grpc_server_add_insecure_http2_port server listening in
  grpc_server_start server;
  { server; cq; port }

let destroy_server server =
  grpc_server_shutdown_and_notify server.server server.cq null;
  grpc_server_cancel_all_calls server.server;
  grpc_server_destroy server.server

type call = {
  call : grpc_call structure ptr;
  details : GRPC_call_details.t structure;
  metadatas : GRPC_metadata_array.t structure;
  cq_call : grpc_completion_queue structure ptr;
}

let mk_timespec ?(sec = Int64.max_int) ?(nsec = Int32.zero) () =
  let s = make GPR_timespec.t in
  setf s GPR_timespec.tv_sec sec;
  setf s GPR_timespec.tv_nsec nsec;
  setf s GPR_timespec.clock_type GPR_clock_type.GPR_TIMESPAN;
  s

exception QUEUE_SHUTDOWN

type wait_call = TIMEOUT | CALL of call

let wait_call ?timeout server =
  let call = allocate_n (ptr grpc_call) ~count:1 in
  let details = make GRPC_call_details.t in
  let metadatas = make GRPC_metadata_array.t in
  let cq_call = grpc_completion_queue_create_for_next null in
  let tag = to_voidp (addr details) in
  let call_error =
    grpc_server_request_call server.server call (addr details) (addr metadatas)
      cq_call server.cq tag
  in
  match call_error with
  | GRPC_CALL_OK -> (
      let deadline = mk_timespec ?sec:timeout () in
      let grpc_event =
        grpc_completion_queue_pluck server.cq tag deadline null
      in
      match getf grpc_event GRPC_event.type_ with
      | GRPC_QUEUE_SHUTDOWN -> raise QUEUE_SHUTDOWN
      | GRPC_QUEUE_TIMEOUT -> TIMEOUT
      | GRPC_OP_COMPLETE ->
          let call = !@call in
          CALL { call; details; metadatas; cq_call })
  | e -> invalid_arg (grpc_call_error_to_string e)
