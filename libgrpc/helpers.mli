exception QUEUE_SHUTDOWN

exception TIMEOUT

module Op : sig
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

  val show_status_code : status_code -> string

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

  val o : t -> (module O)
end

module Server : sig
  type t

  val create : listening:string -> unit -> t

  val destroy : t -> unit

  type wait_call = {
    call : Call.t;
    details : Core.GRPC_call_details.t Ctypes.structure;
    metadatas : (string * string) list;
  }

  val wait_call : ?timeout:int64 -> t -> wait_call
end

module Client : sig
  type t

  val create : target:string -> unit -> t

  val destroy : t -> unit

  type call_result = TIMEOUT | CALL

  val call : meth:string -> ?timeout:int64 -> t -> Call.t
end
