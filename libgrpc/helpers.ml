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

  let of_list ~dst_size ~dst_metadatas l =
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
    dst_size <-@ Unsigned.Size_t.of_int len;
    dst_metadatas <-@ CArray.start metadatas;
    metadatas
end

module Op = struct
  type status_code = Types_generated.GRPC_status_code.t =
    | GRPC_STATUS_OK
    | GRPC_STATUS_CANCELLED
    | GRPC_STATUS_UNKNOWN
    | GRPC_STATUS_INVALID_ARGUMENT
    | GRPC_STATUS_DEADLINE_EXCEEDED
    | GRPC_STATUS_NOT_FOUND
    | GRPC_STATUS_ALREADY_EXISTS
    | GRPC_STATUS_PERMISSION_DENIED
    | GRPC_STATUS_UNAUTHENTICATED
    | GRPC_STATUS_RESOURCE_EXHAUSTED
    | GRPC_STATUS_FAILED_PRECONDITION
    | GRPC_STATUS_ABORTED
    | GRPC_STATUS_OUT_OF_RANGE
    | GRPC_STATUS_UNIMPLEMENTED
    | GRPC_STATUS_INTERNAL
    | GRPC_STATUS_UNAVAILABLE
    | GRPC_STATUS_DATA_LOSS
    | GRPC_STATUS__DO_NOT_USE

  type t =
    | SEND_INITIAL_METADATA of (string * string) list
    | SEND_MESSAGE of string
    | SEND_CLOSE_FROM_CLIENT
    | SEND_STATUS_FROM_SERVER of {
        trailing_metadata : (string * string) list;
        status : status_code;
        status_details : string option;
      }
    | RECV_INITIAL_METADATA of (string * string) list ref
    | RECV_MESSAGE of string ref
    | RECV_STATUS_ON_CLIENT of {
        trailing_metadata : (string * string) list ref;
        status : status_code ref;
        status_details : string ref;
      }
    | RECV_CLOSE_ON_SERVER of { cancelled : bool ref }

  let op_send_initial_metadata l =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_INITIAL_METADATA;
    let initial =
      getf (getf op GRPC_op.data) GRPC_op.Data.send_initial_metadata
    in
    let metadatas =
      Metadata_array.of_list
        ~dst_size:(initial @. GRPC_op.Data.Send_initial_metadata.count)
        ~dst_metadatas:(initial @. GRPC_op.Data.Send_initial_metadata.metadata)
        l
    in
    ( op,
      fun () ->
        Cstubs_internals.use_value op;
        Cstubs_internals.use_value metadatas )

  let op_recv_initial_metadata r =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_INITIAL_METADATA;
    let metadata_array = make GRPC_metadata_array.t in
    grpc_metadata_array_init (addr metadata_array);
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_initial_metadata in
    setf recv GRPC_op.Data.Recv_initial_metadata.recv_initial_metadata
      (addr metadata_array);
    let filler () =
      Cstubs_internals.use_value op;

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
    (op, fun () -> Cstubs_internals.use_value op)

  let op_recv_message rmsg =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_MESSAGE;
    let recv_message = allocate_n (ptr GRPC_byte_buffer.t) ~count:1 in
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_message in
    setf recv GRPC_op.Data.Recv_message.recv_message recv_message;
    let filler () =
      Cstubs_internals.use_value op;
      rmsg := Byte_buffer.to_string !@(!@recv_message);
      grpc_byte_buffer_destroy !@recv_message
    in
    (op, filler)

  let op_send_close_from_client () =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_CLOSE_FROM_CLIENT;
    (op, fun () -> Cstubs_internals.use_value op)

  let op_send_status_from_server ~trailing_metadata ~status ~status_details =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_STATUS_FROM_SERVER;
    let data =
      getf (getf op GRPC_op.data) GRPC_op.Data.send_status_from_server
    in
    let metadatas =
      Metadata_array.of_list
        ~dst_size:
          (data @. GRPC_op.Data.Send_status_from_server.trailing_metadata_count)
        ~dst_metadatas:
          (data @. GRPC_op.Data.Send_status_from_server.trailing_metadata)
        trailing_metadata
    in
    setf data GRPC_op.Data.Send_status_from_server.status status;
    let status_details =
      Option.map (fun sd -> slice_of_string sd) status_details
    in
    let status_details_ptr = Option.map addr status_details in
    setf data GRPC_op.Data.Send_status_from_server.status_details
      status_details_ptr;
    ( op,
      fun () ->
        Cstubs_internals.use_value op;
        Cstubs_internals.use_value metadatas;
        Cstubs_internals.use_value status_details )

  let op_recv_status_on_client ~trailing_metadata ~status ~status_details =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_STATUS_ON_CLIENT;
    let metadata_array = make GRPC_metadata_array.t in
    grpc_metadata_array_init (addr metadata_array);
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_status_on_client in
    setf recv GRPC_op.Data.Recv_status_on_client.trailing_metadata
      (addr metadata_array);
    let rstatus = allocate_n GRPC_status_code.t ~count:1 in
    setf recv GRPC_op.Data.Recv_status_on_client.status rstatus;
    let rstatus_details = make GRPC_slice.t in
    setf recv GRPC_op.Data.Recv_status_on_client.status_details
      (addr rstatus_details);
    let filler () =
      Cstubs_internals.use_value op;
      trailing_metadata := Metadata_array.to_list metadata_array;
      grpc_metadata_array_destroy (addr metadata_array);
      status := !@rstatus;
      status_details := string_of_slice rstatus_details;
      Option.iter
        (fun p -> gpr_free (to_voidp p))
        (getf recv GRPC_op.Data.Recv_status_on_client.error_string)
    in
    (op, filler)

  let op_recv_close_on_server ~cancelled =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_CLOSE_ON_SERVER;
    let recv_cancelled = allocate_n int ~count:1 in
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_close_on_server in
    setf recv GRPC_op.Data.Recv_close_on_server.cancelled recv_cancelled;
    let filler () =
      Cstubs_internals.use_value op;
      cancelled := not (Int.equal !@recv_cancelled 0)
    in
    (op, filler)

  let to_grpc = function
    | SEND_INITIAL_METADATA l -> op_send_initial_metadata l
    | RECV_INITIAL_METADATA r -> op_recv_initial_metadata r
    | SEND_MESSAGE msg -> op_send_message msg
    | RECV_MESSAGE rmsg -> op_recv_message rmsg
    | SEND_CLOSE_FROM_CLIENT -> op_send_close_from_client ()
    | SEND_STATUS_FROM_SERVER { trailing_metadata; status; status_details } ->
        op_send_status_from_server ~trailing_metadata ~status ~status_details
    | RECV_STATUS_ON_CLIENT { trailing_metadata; status; status_details } ->
        op_recv_status_on_client ~trailing_metadata ~status ~status_details
    | RECV_CLOSE_ON_SERVER { cancelled } -> op_recv_close_on_server ~cancelled
end

module Call = struct
  type t = {
    call : grpc_call structure ptr;
    cq : grpc_completion_queue structure ptr;
  }

  let send_ops ?timeout call ops =
    let ops, filler = List.split @@ List.map Op.to_grpc ops in
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

  module type O = sig
    type 'a t

    val send_initial_metadata : (string * string) list -> unit t

    val send_message : string -> unit t

    val send_close_from_client : unit t

    val send_status_from_server :
      ?trailing_metadata:(string * string) list ->
      ?status_details:string ->
      Op.status_code ->
      unit t

    val recv_initial_metadata : unit -> (string * string) list t

    val recv_message : unit -> string t

    type status_on_client = {
      trailing_metadata : (string * string) list;
      status : Op.status_code;
      status_details : string;
    }

    val recv_status_on_client : unit -> status_on_client t

    val recv_close_on_server : unit -> bool t

    val timeout : int64 -> unit t

    val ( let> ) : 'a t -> ('a -> 'b) -> 'b

    val ( and> ) : 'a t -> 'b t -> ('a * 'b) t
  end

  let o call =
    let module M = struct
      type 'a t = { ops : Op.t list; reader : unit -> 'a; timeout : int64 }

      let send_initial_metadata l =
        {
          timeout = Int64.max_int;
          ops = [ Op.SEND_INITIAL_METADATA l ];
          reader = (fun () -> ());
        }

      let send_message s =
        {
          timeout = Int64.max_int;
          ops = [ Op.SEND_MESSAGE s ];
          reader = (fun () -> ());
        }

      let send_close_from_client =
        {
          timeout = Int64.max_int;
          ops = [ Op.SEND_CLOSE_FROM_CLIENT ];
          reader = (fun () -> ());
        }

      let send_status_from_server ?(trailing_metadata = []) ?status_details
          status =
        {
          timeout = Int64.max_int;
          ops =
            [
              Op.SEND_STATUS_FROM_SERVER
                { trailing_metadata; status_details; status };
            ];
          reader = (fun () -> ());
        }

      let recv_initial_metadata () =
        let l = ref [] in
        {
          timeout = Int64.max_int;
          ops = [ Op.RECV_INITIAL_METADATA l ];
          reader = (fun () -> !l);
        }

      let recv_message () =
        let l = ref "" in
        {
          timeout = Int64.max_int;
          ops = [ Op.RECV_MESSAGE l ];
          reader = (fun () -> !l);
        }

      type status_on_client = {
        trailing_metadata : (string * string) list;
        status : Op.status_code;
        status_details : string;
      }

      let recv_status_on_client () =
        let trailing_metadata = ref [] in
        let status = ref Op.GRPC_STATUS__DO_NOT_USE in
        let status_details = ref "" in
        {
          timeout = Int64.max_int;
          ops =
            [
              Op.RECV_STATUS_ON_CLIENT
                { trailing_metadata; status; status_details };
            ];
          reader =
            (fun () ->
              {
                trailing_metadata = !trailing_metadata;
                status = !status;
                status_details = !status_details;
              });
        }

      let recv_close_on_server () =
        let cancelled = ref false in
        {
          timeout = Int64.max_int;
          ops = [ Op.RECV_CLOSE_ON_SERVER { cancelled } ];
          reader = (fun () -> !cancelled);
        }

      let timeout timeout = { timeout; ops = []; reader = (fun () -> ()) }

      let ( let> ) ops f =
        send_ops ~timeout:ops.timeout call ops.ops;
        f (ops.reader ())

      let ( and> ) ops1 ops2 =
        {
          timeout = Int64.min ops1.timeout ops2.timeout;
          ops = ops1.ops @ ops2.ops;
          reader = (fun () -> (ops1.reader (), ops2.reader ()));
        }
    end in
    (module M : O)
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
