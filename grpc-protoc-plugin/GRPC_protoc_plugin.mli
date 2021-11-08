type ('req, 'rep) service =
  (module Ocaml_protoc_plugin.Service.Message with type t = 'req)
  * (module Ocaml_protoc_plugin.Service.Message with type t = 'rep)

module Server : sig
  val simple_rpc :
    GRPC.Server.received_call -> ('req, 'rep) service -> ('req -> 'rep) -> unit
end

module Client : sig
  val simple_rpc :
    GRPC.Client.t ->
    meth:string ->
    ?timeout:int64 ->
    ('req, 'rep) service ->
    'req ->
    'rep
end
