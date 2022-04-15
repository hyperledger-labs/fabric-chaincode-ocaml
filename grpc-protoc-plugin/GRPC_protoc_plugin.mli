open Ocaml_protoc_plugin.Service

module Server : sig
  type registered

  val serve :
    ?timeout:int64 -> GRPC.Server.received_call -> registered list -> unit
  (** Serve the request *)

  val unary_rpc : ('req, 'rep, no, no) service -> ('req -> 'rep) -> registered

  type 'rep server_stream = 'rep -> unit
  type 'req client_stream = unit -> 'req option

  val client_stream_rpc :
    ('req, 'rep, yes, no) service -> ('req client_stream -> 'rep) -> registered

  val server_stream_rpc :
    ('req, 'rep, no, yes) service ->
    ('req -> 'rep server_stream -> unit) ->
    registered

  val bidirectional_stream_rpc :
    ('req, 'rep, yes, yes) service ->
    ('req client_stream -> 'rep server_stream -> unit) ->
    registered
end

module Client : sig
  val unary_rpc :
    ?timeout:int64 ->
    GRPC.Client.t ->
    ('req, 'rep, no, no) service ->
    'req ->
    'rep

  type 'req client_stream = 'req -> unit
  type 'rep server_stream = unit -> 'rep option

  val client_stream_rpc :
    ?timeout:int64 ->
    GRPC.Client.t ->
    ('req, 'rep, yes, no) service ->
    ('req client_stream -> unit) ->
    'rep

  val server_stream_rpc :
    ?timeout:int64 ->
    GRPC.Client.t ->
    ('req, 'rep, no, yes) service ->
    'req ->
    ('rep server_stream -> 'a) ->
    'a * GRPC__Helpers.Status_on_client.t

  val bidirectional_rpc :
    ?timeout:int64 ->
    GRPC.Client.t ->
    ('req, 'rep, yes, yes) service ->
    ('req client_stream -> 'rep server_stream -> 'a) ->
    'a * GRPC__Helpers.Status_on_client.t
end
