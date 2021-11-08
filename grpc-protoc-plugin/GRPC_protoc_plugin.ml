type ('req, 'rep) service =
  (module Ocaml_protoc_plugin__.Service.Rpc
     with type Request.t = 'req
      and type Response.t = 'rep)

module Server = struct
  let make_service_functions (type req rep)
      (module R : Ocaml_protoc_plugin__.Service.Rpc
        with type Request.t = req
         and type Response.t = rep) =
    (R.Request.from_proto, R.Response.to_proto, R.name' ())

  let simple_rpc call conv f =
    let from_proto, to_proto, name = make_service_functions conv in
    assert (call.GRPC.Server.method_ = name);
    GRPC.Server.simple_rpc call (fun msg ->
        let msg = Ocaml_protoc_plugin.Reader.create msg in
        let msg = Result.get_ok (from_proto msg) in
        let rcp = f msg in
        to_proto rcp |> Ocaml_protoc_plugin.Writer.contents)
end

module Client = struct
  let make_client_functions (type req rep)
      (module R : Ocaml_protoc_plugin__.Service.Rpc
        with type Request.t = req
         and type Response.t = rep) =
    (R.Request.to_proto, R.Response.from_proto, R.name' ())

  let simple_rpc t ?timeout conv msg =
    let to_proto, from_proto, meth = make_client_functions conv in
    let rcp =
      GRPC.Client.simple_rpc t ~meth ?timeout
        (to_proto msg |> Ocaml_protoc_plugin.Writer.contents)
    in
    rcp |> Ocaml_protoc_plugin.Reader.create |> from_proto |> Result.get_ok
end
