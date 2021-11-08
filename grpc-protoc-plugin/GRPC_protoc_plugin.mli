type ('req, 'rep) service =
  (module Ocaml_protoc_plugin__.Service.Rpc
     with type Request.t = 'req
      and type Response.t = 'rep)

module Server : sig
  val simple_rpc :
    GRPC.Server.received_call -> ('req, 'rep) service -> ('req -> 'rep) -> unit
end

module Client : sig
  val simple_rpc :
    GRPC.Client.t -> ?timeout:int64 -> ('req, 'rep) service -> 'req -> 'rep
end
