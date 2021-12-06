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
  type status_code_error =
    | CANCELLED
    | UNKNOWN
    | INVALID_ARGUMENT
    | DEADLINE_EXCEEDED
    | NOT_FOUND
    | ALREADY_EXISTS
    | PERMISSION_DENIED
    | UNAUTHENTICATED
    | RESOURCE_EXHAUSTED
    | FAILED_PRECONDITION
    | ABORTED
    | OUT_OF_RANGE
    | UNIMPLEMENTED
    | INTERNAL
    | UNAVAILABLE
    | DATA_LOSS
    | DO_NOT_USE

  let to_grpc_status = function
    | None -> GRPC_status_code.GRPC_STATUS_OK
    | Some CANCELLED -> GRPC_status_code.GRPC_STATUS_CANCELLED
    | Some UNKNOWN -> GRPC_status_code.GRPC_STATUS_UNKNOWN
    | Some INVALID_ARGUMENT -> GRPC_status_code.GRPC_STATUS_INVALID_ARGUMENT
    | Some DEADLINE_EXCEEDED -> GRPC_status_code.GRPC_STATUS_DEADLINE_EXCEEDED
    | Some NOT_FOUND -> GRPC_status_code.GRPC_STATUS_NOT_FOUND
    | Some ALREADY_EXISTS -> GRPC_status_code.GRPC_STATUS_ALREADY_EXISTS
    | Some PERMISSION_DENIED -> GRPC_status_code.GRPC_STATUS_PERMISSION_DENIED
    | Some UNAUTHENTICATED -> GRPC_status_code.GRPC_STATUS_UNAUTHENTICATED
    | Some RESOURCE_EXHAUSTED -> GRPC_status_code.GRPC_STATUS_RESOURCE_EXHAUSTED
    | Some FAILED_PRECONDITION ->
        GRPC_status_code.GRPC_STATUS_FAILED_PRECONDITION
    | Some ABORTED -> GRPC_status_code.GRPC_STATUS_ABORTED
    | Some OUT_OF_RANGE -> GRPC_status_code.GRPC_STATUS_OUT_OF_RANGE
    | Some UNIMPLEMENTED -> GRPC_status_code.GRPC_STATUS_UNIMPLEMENTED
    | Some INTERNAL -> GRPC_status_code.GRPC_STATUS_INTERNAL
    | Some UNAVAILABLE -> GRPC_status_code.GRPC_STATUS_UNAVAILABLE
    | Some DATA_LOSS -> GRPC_status_code.GRPC_STATUS_DATA_LOSS
    | Some DO_NOT_USE -> GRPC_status_code.GRPC_STATUS__DO_NOT_USE

  let show_status_code_error = function
    | CANCELLED -> "CANCELLED"
    | UNKNOWN -> "UNKNOWN"
    | INVALID_ARGUMENT -> "INVALID_ARGUMENT"
    | DEADLINE_EXCEEDED -> "DEADLINE_EXCEEDED"
    | NOT_FOUND -> "NOT_FOUND"
    | ALREADY_EXISTS -> "ALREADY_EXISTS"
    | PERMISSION_DENIED -> "PERMISSION_DENIED"
    | UNAUTHENTICATED -> "UNAUTHENTICATED"
    | RESOURCE_EXHAUSTED -> "RESOURCE_EXHAUSTED"
    | FAILED_PRECONDITION -> "FAILED_PRECONDITION"
    | ABORTED -> "ABORTED"
    | OUT_OF_RANGE -> "OUT_OF_RANGE"
    | UNIMPLEMENTED -> "UNIMPLEMENTED"
    | INTERNAL -> "INTERNAL"
    | UNAVAILABLE -> "UNAVAILABLE"
    | DATA_LOSS -> "DATA_LOSS"
    | DO_NOT_USE -> "DO_NOT_USE"

  exception STATUS_ERROR of status_code_error * string

  let () =
    Printexc.register_printer (function
      | STATUS_ERROR (sc, s) ->
          Some
            (Printf.sprintf "GRPC:STATUS_ERROR(%s,%S)"
               (show_status_code_error sc)
               s)
      | _ -> None)

  type t =
    | SEND_INITIAL_METADATA of (string * string) list
    | SEND_MESSAGE of string
    | SEND_CLOSE_FROM_CLIENT
    | SEND_STATUS_FROM_SERVER of {
        trailing_metadata : (string * string) list;
        status : status_code_error option;
        status_details : string option;
      }
    | RECV_INITIAL_METADATA of (string * string) list ref
    | RECV_MESSAGE of string ref
    | RECV_STATUS_ON_CLIENT of {
        trailing_metadata : (string * string) list ref;
        status_details : string ref;
      }
    | RECV_CLOSE_ON_SERVER of { cancelled : bool ref }

  type pre_post = {
    op : GRPC_op.t structure;
    filler : unit -> unit;
    cleanup : unit -> unit;
    check : unit -> unit;
  }

  let pre_post ?(filler = fun () -> ()) ?(cleanup = fun () -> ())
      ?(check = fun () -> ()) op =
    { op; filler; cleanup; check }

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
    pre_post op ~cleanup:(fun () -> Cstubs_internals.use_value metadatas)

  let op_recv_initial_metadata r =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_INITIAL_METADATA;
    let metadata_array = make GRPC_metadata_array.t in
    grpc_metadata_array_init (addr metadata_array);
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_initial_metadata in
    setf recv GRPC_op.Data.Recv_initial_metadata.recv_initial_metadata
      (addr metadata_array);
    let filler () = r := Metadata_array.to_list metadata_array in
    let cleanup () =
      Cstubs_internals.use_value op;
      grpc_metadata_array_destroy (addr metadata_array)
    in
    pre_post op ~filler ~cleanup

  let op_send_message msg =
    let send_message = make GRPC_byte_buffer.t in
    Byte_buffer.of_string ~dst:send_message msg;
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_MESSAGE;
    let initial = getf (getf op GRPC_op.data) GRPC_op.Data.send_message in
    setf initial GRPC_op.Data.Send_message.send_message (addr send_message);
    pre_post op ~cleanup:(fun () -> Cstubs_internals.use_value op)

  let op_recv_message rmsg =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_MESSAGE;
    let recv_message =
      allocate (ptr GRPC_byte_buffer.t) (from_voidp GRPC_byte_buffer.t null)
    in
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_message in
    setf recv GRPC_op.Data.Recv_message.recv_message recv_message;
    let filler () = rmsg := Byte_buffer.to_string !@(!@recv_message) in
    let cleanup () = grpc_byte_buffer_destroy !@recv_message in
    pre_post op ~filler ~cleanup

  let op_send_close_from_client () =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_SEND_CLOSE_FROM_CLIENT;
    pre_post op ~cleanup:(fun () -> Cstubs_internals.use_value op)

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
    setf data GRPC_op.Data.Send_status_from_server.status
      (to_grpc_status status);
    let status_details =
      Option.map (fun sd -> slice_of_string sd) status_details
    in
    let status_details_ptr = Option.map addr status_details in
    setf data GRPC_op.Data.Send_status_from_server.status_details
      status_details_ptr;
    pre_post op ~cleanup:(fun () ->
        Cstubs_internals.use_value metadatas;
        Cstubs_internals.use_value status_details)

  let op_recv_status_on_client ~trailing_metadata ~status_details =
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
      trailing_metadata := Metadata_array.to_list metadata_array;
      status_details := string_of_slice rstatus_details
    in
    let cleanup () =
      Cstubs_internals.use_value op;
      grpc_metadata_array_destroy (addr metadata_array);
      Option.iter
        (fun p -> gpr_free (to_voidp p))
        (getf recv GRPC_op.Data.Recv_status_on_client.error_string)
    in
    pre_post op ~filler ~cleanup ~check:(fun () ->
        let raise_status_error error =
          let details = string_of_slice rstatus_details in
          raise (STATUS_ERROR (error, details))
        in
        match !@rstatus with
        | GRPC_status_code.GRPC_STATUS_OK -> ()
        | GRPC_STATUS_CANCELLED -> raise_status_error CANCELLED
        | GRPC_STATUS_UNKNOWN -> raise_status_error UNKNOWN
        | GRPC_STATUS_INVALID_ARGUMENT -> raise_status_error INVALID_ARGUMENT
        | GRPC_STATUS_DEADLINE_EXCEEDED -> raise_status_error DEADLINE_EXCEEDED
        | GRPC_STATUS_NOT_FOUND -> raise_status_error NOT_FOUND
        | GRPC_STATUS_ALREADY_EXISTS -> raise_status_error ALREADY_EXISTS
        | GRPC_STATUS_PERMISSION_DENIED -> raise_status_error PERMISSION_DENIED
        | GRPC_STATUS_UNAUTHENTICATED -> raise_status_error UNAUTHENTICATED
        | GRPC_STATUS_RESOURCE_EXHAUSTED ->
            raise_status_error RESOURCE_EXHAUSTED
        | GRPC_STATUS_FAILED_PRECONDITION ->
            raise_status_error FAILED_PRECONDITION
        | GRPC_STATUS_ABORTED -> raise_status_error ABORTED
        | GRPC_STATUS_OUT_OF_RANGE -> raise_status_error OUT_OF_RANGE
        | GRPC_STATUS_UNIMPLEMENTED -> raise_status_error UNIMPLEMENTED
        | GRPC_STATUS_INTERNAL -> raise_status_error INTERNAL
        | GRPC_STATUS_UNAVAILABLE -> raise_status_error UNAVAILABLE
        | GRPC_STATUS_DATA_LOSS -> raise_status_error DATA_LOSS
        | GRPC_STATUS__DO_NOT_USE -> raise_status_error DO_NOT_USE)

  let op_recv_close_on_server ~cancelled =
    let op = make GRPC_op.t in
    setf op GRPC_op.op GRPC_op_type.GRPC_OP_RECV_CLOSE_ON_SERVER;
    let recv_cancelled = allocate_n int ~count:1 in
    let recv = getf (getf op GRPC_op.data) GRPC_op.Data.recv_close_on_server in
    setf recv GRPC_op.Data.Recv_close_on_server.cancelled recv_cancelled;
    let filler () = cancelled := not (Int.equal !@recv_cancelled 0) in
    let cleanup () = Cstubs_internals.use_value op in
    pre_post op ~filler ~cleanup ~check:(fun () ->
        if not (Int.equal !@recv_cancelled 0) then
          raise (STATUS_ERROR (UNKNOWN, "Recv_close_from_client")))

  let to_grpc = function
    | SEND_INITIAL_METADATA l -> op_send_initial_metadata l
    | RECV_INITIAL_METADATA r -> op_recv_initial_metadata r
    | SEND_MESSAGE msg -> op_send_message msg
    | RECV_MESSAGE rmsg -> op_recv_message rmsg
    | SEND_CLOSE_FROM_CLIENT -> op_send_close_from_client ()
    | SEND_STATUS_FROM_SERVER { trailing_metadata; status; status_details } ->
        op_send_status_from_server ~trailing_metadata ~status ~status_details
    | RECV_STATUS_ON_CLIENT { trailing_metadata; status_details } ->
        op_recv_status_on_client ~trailing_metadata ~status_details
    | RECV_CLOSE_ON_SERVER { cancelled } -> op_recv_close_on_server ~cancelled
end

module Call = struct
  type t = {
    call : grpc_call structure ptr;
    cq : grpc_completion_queue structure ptr;
  }

  let send_ops ?timeout call ops =
    let pre_posts = List.map Op.to_grpc ops in
    let ops_len = Unsigned.Size_t.of_int @@ List.length pre_posts in
    let ops =
      CArray.of_list GRPC_op.t (List.map (fun p -> p.Op.op) pre_posts)
    in
    let deadline = mk_timespec ?sec:timeout () in
    Fun.protect
      ~finally:(fun () -> List.iter (fun p -> p.Op.cleanup ()) pre_posts)
      (fun () ->
        match
          grpc_call_start_batch call.call (CArray.start ops) ops_len null null
        with
        | GRPC_CALL_OK -> (
            let grpc_event = grpc_completion_queue_next call.cq deadline null in
            match getf grpc_event GRPC_event.type_ with
            | GRPC_QUEUE_SHUTDOWN -> raise QUEUE_SHUTDOWN
            | GRPC_QUEUE_TIMEOUT -> raise TIMEOUT
            | GRPC_OP_COMPLETE ->
                List.iter (fun p -> p.Op.check ()) pre_posts;
                List.iter (fun p -> p.Op.filler ()) pre_posts)
        | e -> invalid_arg (grpc_call_error_to_string e))

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
      ?status:Op.status_code_error ->
      unit ->
      unit t

    val recv_initial_metadata : unit -> (string * string) list t

    val recv_message : unit -> string t

    type status_on_client = {
      trailing_metadata : (string * string) list;
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
          ?status () =
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
        status_details : string;
      }

      let recv_status_on_client () =
        let trailing_metadata = ref [] in
        let status_details = ref "" in
        {
          timeout = Int64.max_int;
          ops =
            [ Op.RECV_STATUS_ON_CLIENT { trailing_metadata; status_details } ];
          reader =
            (fun () ->
              {
                trailing_metadata = !trailing_metadata;
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

  type received_call = {
    call : Call.t;
    method_ : string;
    host : string;
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
            let method_ =
              string_of_slice @@ getf details GRPC_call_details.method_
            in
            let host = string_of_slice @@ getf details GRPC_call_details.host in
            grpc_call_details_destroy (addr details);
            {
              call = { call; cq = cq_call };
              method_;
              host;
              metadatas = Metadata_array.to_list metadatas;
            })
    | e -> invalid_arg (grpc_call_error_to_string e)

  let unary_rpc c f =
    let open (val Call.o c.call) in
    let> msg = recv_message () in
    let rsp = f msg in
    let> () = send_initial_metadata []
    and> _ = recv_close_on_server ()
    and> () = send_message rsp
    and> () = send_status_from_server () in
    ()

  type server_stream = string -> unit

  type client_stream = unit -> string

  let client_stream_rpc c (f : client_stream -> string) =
    let open (val Call.o c.call) in
    let client_stream () =
      let> msg = recv_message () in
      msg
    in
    let> () = send_initial_metadata [] in
    let rsp = f client_stream in
    let> _ = recv_close_on_server ()
    and> () = send_message rsp
    and> () = send_status_from_server () in
    ()

  let server_stream_rpc c f =
    let open (val Call.o c.call) in
    let server_stream msg =
      let> msg = send_message msg in
      ()
    in
    let> msg = recv_message () and> () = send_initial_metadata [] in
    f msg server_stream;
    let> _ = recv_close_on_server () and> () = send_status_from_server () in
    ()

  let bidirectional_rpc c f =
    let open (val Call.o c.call) in
    let client_stream () =
      let> msg = recv_message () in
      msg
    in
    let server_stream msg =
      let> msg = send_message msg in
      ()
    in
    let> () = send_initial_metadata [] in
    f client_stream server_stream;
    let> _ = recv_close_on_server () and> () = send_status_from_server () in
    ()
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

  let unary_rpc ~meth ?timeout c msg =
    let c = call ~meth ?timeout c in
    let open (val Call.o c) in
    let> () = send_initial_metadata []
    and> () = send_message msg
    and> () = send_close_from_client in
    let> _ = recv_initial_metadata ()
    and> rcp = recv_message ()
    and> status = recv_status_on_client () in
    rcp

  type client_stream = string -> unit

  type server_stream = unit -> string

  let client_stream_rpc ~meth ?timeout c (f : client_stream -> unit) =
    let c = call ~meth ?timeout c in
    let open (val Call.o c) in
    let client_stream msg =
      let> () = send_message msg in
      ()
    in
    let> () = send_initial_metadata [] and> _ = recv_initial_metadata () in
    f client_stream;
    let> () = send_close_from_client
    and> rcp = recv_message ()
    and> status = recv_status_on_client () in
    rcp

  let server_stream_rpc ~meth ?timeout c msg (f : server_stream -> 'a) : 'a =
    let c = call ~meth ?timeout c in
    let open (val Call.o c) in
    let server_stream () =
      let> msg = recv_message () in
      msg
    in
    let> () = send_initial_metadata []
    and> () = send_message msg
    and> _ = recv_initial_metadata ()
    and> () = send_close_from_client in
    let r = f server_stream in
    let> _ = recv_status_on_client () in
    r

  let bidirectional_rpc ~meth ?timeout c
      (f : client_stream -> server_stream -> 'a) : 'a =
    let c = call ~meth ?timeout c in
    let open (val Call.o c) in
    let first = ref true in
    let client_stream msg =
      if !first then
        let> () = send_message msg and> _ = recv_initial_metadata () in
        first := false
      else
        let> () = send_message msg in
        ()
    in
    let server_stream () =
      let> msg = recv_message () in
      msg
    in
    let> () = send_initial_metadata [] in
    let r = f client_stream server_stream in
    let> () = send_close_from_client and> _ = recv_status_on_client () in
    r
end
