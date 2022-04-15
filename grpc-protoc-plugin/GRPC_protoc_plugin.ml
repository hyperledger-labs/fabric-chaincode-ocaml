let from_proto_stream from_proto msgs () =
  (Option.map (fun msg ->
       let msg = Ocaml_protoc_plugin.Reader.create msg in
       Result.get_ok (from_proto msg)))
    (msgs ())

let to_proto_stream to_proto rcps rcp =
  to_proto rcp |> Ocaml_protoc_plugin.Writer.contents |> rcps

module Server = struct
  type registered = {
    name : string;
    serve : ?timeout:int64 -> GRPC.Server.received_call -> unit;
  }

  let serve ?timeout call regs =
    let reg =
      List.find_opt (fun reg -> reg.name = call.GRPC.Server.method_) regs
      |> Option.get
    in
    reg.serve ?timeout call

  let register conv serve =
    let name, from_proto, to_proto =
      Ocaml_protoc_plugin.Service.make_service_functions' conv
    in
    {
      name;
      serve =
        (fun ?timeout:_ call ->
          assert (call.GRPC.Server.method_ = name);
          serve call from_proto to_proto);
    }

  let unary_rpc conv f =
    register conv (fun call from_proto to_proto ->
        GRPC.Server.unary_rpc call (fun msg ->
            let msg = Ocaml_protoc_plugin.Reader.create msg in
            let msg = Result.get_ok (from_proto msg) in
            let rcp = f msg in
            to_proto rcp |> Ocaml_protoc_plugin.Writer.contents))

  type 'rep server_stream = 'rep -> unit
  type 'req client_stream = unit -> 'req option

  let client_stream_rpc conv f =
    register conv (fun call from_proto to_proto ->
        GRPC.Server.client_stream_rpc call (fun msgs ->
            let msgs = from_proto_stream from_proto msgs in
            let rcp = f msgs in
            to_proto rcp |> Ocaml_protoc_plugin.Writer.contents))

  let server_stream_rpc conv f =
    register conv (fun call from_proto to_proto ->
        GRPC.Server.server_stream_rpc call (fun msg rcps ->
            let rcps = to_proto_stream to_proto rcps in
            let msg = Ocaml_protoc_plugin.Reader.create msg in
            let msg = Result.get_ok (from_proto msg) in
            f msg rcps))

  let bidirectional_stream_rpc conv f =
    register conv (fun call from_proto to_proto ->
        GRPC.Server.bidirectional_rpc call (fun msgs rcps ->
            let msgs = from_proto_stream from_proto msgs in
            let rcps = to_proto_stream to_proto rcps in
            f msgs rcps))
end

module Client = struct
  let unary_rpc ?timeout t conv msg =
    let meth, to_proto, from_proto =
      Ocaml_protoc_plugin.Service.make_client_functions' conv
    in
    let rcp =
      GRPC.Client.unary_rpc t ~meth ?timeout
        (to_proto msg |> Ocaml_protoc_plugin.Writer.contents)
    in
    rcp |> Result.get_ok |> Ocaml_protoc_plugin.Reader.create |> from_proto
    |> Result.get_ok

  type 'req client_stream = 'req -> unit
  type 'rep server_stream = unit -> 'rep option

  let client_stream_rpc ?timeout t conv (f : _ client_stream -> unit) =
    let meth, to_proto, from_proto =
      Ocaml_protoc_plugin.Service.make_client_functions' conv
    in
    let f msgs = f (to_proto_stream to_proto msgs) in
    let rcp = GRPC.Client.client_stream_rpc t ~meth ?timeout f in
    rcp |> Result.get_ok |> Ocaml_protoc_plugin.Reader.create |> from_proto
    |> Result.get_ok

  let server_stream_rpc ?timeout t conv msg f =
    let meth, to_proto, from_proto =
      Ocaml_protoc_plugin.Service.make_client_functions' conv
    in
    let f rcps = f (from_proto_stream from_proto rcps) in
    GRPC.Client.server_stream_rpc t ~meth ?timeout
      (to_proto msg |> Ocaml_protoc_plugin.Writer.contents)
      f

  let bidirectional_rpc ?timeout t conv f =
    let meth, to_proto, from_proto =
      Ocaml_protoc_plugin.Service.make_client_functions' conv
    in
    let f msgs rcps =
      f (to_proto_stream to_proto msgs) (from_proto_stream from_proto rcps)
    in
    GRPC.Client.bidirectional_rpc t ~meth ?timeout f
end
