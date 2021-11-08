open Core
open Ctypes

let () = grpc_init ()

let () = at_exit (fun () -> grpc_shutdown ())

let mk_timespec ?(sec = Int64.max_int) ?(nsec = Int32.zero) () =
  let s = make GPR_timespec.t in
  setf s GPR_timespec.tv_sec sec;
  setf s GPR_timespec.tv_nsec nsec;
  setf s GPR_timespec.clock_type GPR_clock_type.GPR_TIMESPAN;
  s

exception QUEUE_SHUTDOWN

exception TIMEOUT

module Slice_buffer = struct
  let to_string sb =
    let len = Unsigned.Size_t.to_int @@ getf sb GRPC_slice_buffer.length in
    let count = Unsigned.Size_t.to_int (getf sb GRPC_slice_buffer.count) in
    let slices = CArray.from_ptr (getf sb GRPC_slice_buffer.slices) count in
    let dst = Bytes.create len in
    let dst_off = ref 0 in
    CArray.iter
      (fun slice ->
        let src = grpc_slice_start_ptr slice in
        let len = Unsigned.Size_t.to_int @@ grpc_slice_length slice in
        Memcpy.(
          unsafe_memcpy pointer ocaml_bytes ~src ~dst ~src_off:0
            ~dst_off:!dst_off ~len);
        dst_off := !dst_off + len)
      slices;
    assert (len = !dst_off);
    Bytes.unsafe_to_string dst

  let of_string ~dst s =
    grpc_slice_buffer_init dst;
    grpc_slice_buffer_add dst (slice_of_string s)
end

module Byte_buffer = struct
  let to_string sb =
    Slice_buffer.to_string
      (getf
         (getf (getf sb GRPC_byte_buffer.data) GRPC_byte_buffer.Data.raw)
         GRPC_byte_buffer.Data.Compressed_buffer.slice_buffer)

  let of_string ~dst s =
    setf dst GRPC_byte_buffer.type_ GRPC_BB_RAW;
    let raw = getf (getf dst GRPC_byte_buffer.data) GRPC_byte_buffer.Data.raw in
    setf raw GRPC_byte_buffer.Data.Compressed_buffer.compression
      GRPC_COMPRESS_NONE;
    Slice_buffer.of_string
      ~dst:(raw @. GRPC_byte_buffer.Data.Compressed_buffer.slice_buffer)
      s
end

module Metadata_array = struct
  let to_list (metadata_array : GRPC_metadata_array.t structure) =
    let len = getf metadata_array GRPC_metadata_array.count in
    let metadatas =
      CArray.from_ptr
        (getf metadata_array GRPC_metadata_array.metadata)
        (Unsigned.Size_t.to_int len)
    in
    CArray.fold_right
      (fun m acc ->
        let k = string_of_slice @@ getf m GRPC_metadata.key in
        let v = string_of_slice @@ getf m GRPC_metadata.value in
        (k, v) :: acc)
      metadatas []
end

module Ops = struct
  type t =
    | SEND_INITIAL_METADATA of (string * string) list
    | SEND_MESSAGE of string
    | SEND_CLOSE_FROM_CLIENT
    | SEND_STATUS_FROM_SERVER
    | RECV_INITIAL_METADATA of (string * string) list ref
    | RECV_MESSAGE of string ref
    | RECV_STATUS_ON_CLIENT
    | RECV_CLOSE_ON_SERVER

  let op_send_initial_metadata l =
    let len = List.length l in
    let metadatas = CArray.make GRPC_metadata.t len in
    List.iteri
      (fun i (k, v) ->
        let m = CArray.get metadatas i in
        let k = slice_of_string k in
        let v = slice_of_string v in
        setf m GRPC_metadata.key k;
        setf m GRPC_metadata.value v)
      l;
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_INITIAL_METADATA;
    let initial =
      getf (getf op GRPC_op.data) GRPC_op.Data.send_initial_metadata
    in
    setf initial GRPC_op.Data.Send_initial_metadata.metadata
      (CArray.start metadatas);
    setf initial GRPC_op.Data.Send_initial_metadata.count
      (Unsigned.Size_t.of_int len);
    (op, fun () -> ())

  let op_recv_initial_metadata r =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_INITIAL_METADATA;
    let metadata_array = make GRPC_metadata_array.t in
    grpc_metadata_array_init (addr metadata_array);
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_initial_metadata in
    setf recv GRPC_op.Data.Recv_initial_metadata.recv_initial_metadata
      (addr metadata_array);
    let filler () =
      r := Metadata_array.to_list metadata_array;
      grpc_metadata_array_destroy (addr metadata_array)
    in
    (op, filler)

  let op_send_message msg =
    let send_message = make GRPC_byte_buffer.t in
    Byte_buffer.of_string ~dst:send_message msg;
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_MESSAGE;
    let initial = getf (getf op GRPC_op.data) GRPC_op.Data.send_message in
    setf initial GRPC_op.Data.Send_message.send_message (addr send_message);
    (op, fun () -> ())

  let op_recv_message rmsg =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_MESSAGE;
    let recv_message = allocate_n (ptr GRPC_byte_buffer.t) ~count:1 in
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_message in
    setf recv GRPC_op.Data.Recv_message.recv_message recv_message;
    let filler () =
      rmsg := Byte_buffer.to_string !@(!@recv_message);
      grpc_byte_buffer_destroy !@recv_message
    in
    (op, filler)

  let to_grpc = function
    | SEND_INITIAL_METADATA l -> op_send_initial_metadata l
    | RECV_INITIAL_METADATA r -> op_recv_initial_metadata r
    | SEND_MESSAGE msg -> op_send_message msg
    | RECV_MESSAGE rmsg -> op_recv_message rmsg
    | SEND_CLOSE_FROM_CLIENT | SEND_STATUS_FROM_SERVER | RECV_STATUS_ON_CLIENT
    | RECV_CLOSE_ON_SERVER ->
        assert false
end

module Call = struct
  type t = {
    call : grpc_call structure ptr;
    cq : grpc_completion_queue structure ptr;
  }

  let send_ops ?timeout call ops =
    let ops, filler = List.split @@ List.map Ops.to_grpc ops in
    let ops_len = Unsigned.Size_t.of_int @@ List.length ops in
    let ops = CArray.of_list GRPC_op.t ops in
    let deadline = mk_timespec ?sec:timeout () in
    match
      grpc_call_start_batch call.call (CArray.start ops) ops_len null null
    with
    | GRPC_CALL_OK -> (
        let grpc_event = grpc_completion_queue_next call.cq deadline null in
        match getf grpc_event GRPC_event.type_ with
        | GRPC_QUEUE_SHUTDOWN -> raise QUEUE_SHUTDOWN
        | GRPC_QUEUE_TIMEOUT -> raise TIMEOUT
        | GRPC_OP_COMPLETE -> List.iter (fun f -> f ()) filler)
    | e -> invalid_arg (grpc_call_error_to_string e)

  let destroy_call call =
    grpc_call_unref call.call;
    grpc_completion_queue_destroy call.cq
end

module Server = struct
  type t = {
    server : grpc_server structure ptr;
    cq : grpc_completion_queue structure ptr;
    port : int;
  }

  let create ~listening () =
    let server = grpc_server_create None null in
    let cq = grpc_completion_queue_create_for_pluck null in
    grpc_server_register_completion_queue server cq null;
    let port = grpc_server_add_insecure_http2_port server listening in
    grpc_server_start server;
    { server; cq; port }

  let destroy server =
    grpc_server_shutdown_and_notify server.server server.cq null;
    grpc_server_cancel_all_calls server.server;
    grpc_server_destroy server.server

  type wait_call = {
    call : Call.t;
    details : GRPC_call_details.t structure;
    metadatas : (string * string) list;
  }

  let wait_call ?timeout server =
    let call = allocate_n (ptr grpc_call) ~count:1 in
    let details = make GRPC_call_details.t in
    let metadatas = make GRPC_metadata_array.t in
    let cq_call = grpc_completion_queue_create_for_next null in
    let tag = to_voidp (addr details) in
    let call_error =
      grpc_server_request_call server.server call (addr details)
        (addr metadatas) cq_call server.cq tag
    in
    match call_error with
    | GRPC_CALL_OK -> (
        let deadline = mk_timespec ?sec:timeout () in
        let grpc_event =
          grpc_completion_queue_pluck server.cq tag deadline null
        in
        match getf grpc_event GRPC_event.type_ with
        | GRPC_QUEUE_SHUTDOWN -> raise QUEUE_SHUTDOWN
        | GRPC_QUEUE_TIMEOUT -> raise TIMEOUT
        | GRPC_OP_COMPLETE ->
            let call = !@call in
            {
              call = { call; cq = cq_call };
              details;
              metadatas = Metadata_array.to_list metadatas;
            })
    | e -> invalid_arg (grpc_call_error_to_string e)
end

module Client = struct
  type t = { channel : grpc_channel structure ptr }

  let create ~target () =
    let channel = grpc_insecure_channel_create target None null in
    { channel }

  let destroy c = grpc_channel_destroy c.channel

  type call_result = TIMEOUT | CALL

  let call ~meth ?timeout c =
    let meth = slice_of_string meth in
    let deadline = mk_timespec ?sec:timeout () in
    let cq = grpc_completion_queue_create_for_next null in
    let call =
      grpc_channel_create_call c.channel None GRPC_propagate_bits.default cq
        meth None deadline null
    in
    grpc_slice_unref meth;
    { Call.call; cq }
end
