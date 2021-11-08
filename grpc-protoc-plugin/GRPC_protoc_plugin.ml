type ('req, 'rep) service =
  (module Ocaml_protoc_plugin.Service.Message with type t = 'req)
  * (module Ocaml_protoc_plugin.Service.Message with type t = 'rep)

module Server = struct
  let simple_rpc call conv f =
    let from_proto, to_proto =
      Ocaml_protoc_plugin.Service.make_service_functions conv
    in
    GRPC.Server.simple_rpc call (fun msg ->
        let msg = Ocaml_protoc_plugin.Reader.create msg in
        let msg = Result.get_ok (from_proto msg) in
        let rcp = f msg in
        to_proto rcp |> Ocaml_protoc_plugin.Writer.contents)
end

module Client = struct
  let simple_rpc t ~meth ?timeout conv msg =
    let to_proto, from_proto =
      Ocaml_protoc_plugin.Service.make_client_functions conv
    in
    let rcp =
      GRPC.Client.simple_rpc t ~meth ?timeout
        (to_proto msg |> Ocaml_protoc_plugin.Writer.contents)
    in
    rcp |> Ocaml_protoc_plugin.Reader.create |> from_proto |> Result.get_ok
end
