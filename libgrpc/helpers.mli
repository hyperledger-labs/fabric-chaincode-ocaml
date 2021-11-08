exception QUEUE_SHUTDOWN

exception TIMEOUT

module Ops : sig
  type t =
    | SEND_INITIAL_METADATA of (string * string) list
    | SEND_MESSAGE of string
    | SEND_CLOSE_FROM_CLIENT
    | SEND_STATUS_FROM_SERVER
    | RECV_INITIAL_METADATA of (string * string) list ref
    | RECV_MESSAGE of string ref
    | RECV_STATUS_ON_CLIENT
    | RECV_CLOSE_ON_SERVER
end

module Call : sig
  type t

  val send_ops : ?timeout:int64 -> t -> Ops.t list -> unit

  val destroy_call : t -> unit
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
