exception QUEUE_SHUTDOWN

exception TIMEOUT

module Op : sig
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

  exception STATUS_ERROR of status_code_error * string

  val show_status_code_error : status_code_error -> string

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
end

module Call : sig
  type t

  val send_ops : ?timeout:int64 -> t -> Op.t list -> unit

  val destroy_call : t -> unit

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

  val o : t -> (module O)
end

module Server : sig
  type t

  val create : listening:string -> unit -> t

  val destroy : t -> unit

  type received_call = {
    call : Call.t;
    method_ : string;
    host : string;
    metadatas : (string * string) list;
  }

  val wait_call : ?timeout:int64 -> t -> received_call

  val unary_rpc : received_call -> (string -> string) -> unit

  type server_stream = string -> unit

  type client_stream = unit -> string

  val client_stream_rpc : received_call -> (client_stream -> string) -> unit

  val server_stream_rpc :
    received_call -> (string -> server_stream -> unit) -> unit

  val bidirectional_rpc :
    received_call -> (client_stream -> server_stream -> unit) -> unit
end

module Client : sig
  type t

  val create : target:string -> unit -> t

  val destroy : t -> unit

  type call_result = TIMEOUT | CALL

  val call : meth:string -> ?timeout:int64 -> t -> Call.t

  val unary_rpc : meth:string -> ?timeout:int64 -> t -> string -> string

  type client_stream = string -> unit

  type server_stream = unit -> string

  val client_stream_rpc :
    meth:string -> ?timeout:int64 -> t -> (client_stream -> unit) -> string

  val server_stream_rpc :
    meth:string -> ?timeout:int64 -> t -> string -> (server_stream -> 'a) -> 'a

  val bidirectional_rpc :
    meth:string ->
    ?timeout:int64 ->
    t ->
    (client_stream -> server_stream -> 'a) ->
    'a
end
