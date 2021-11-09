open GRPC

let listening =
  if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"

let server = Server.create ~listening ()

let services =
  let open Echo.Grpc.Examples.Echo.Echo in
  let open GRPC_protoc_plugin.Server in
  [
    unary_rpc unaryEcho' (fun name -> name);
    client_stream_rpc clientStreamingEcho' (fun msgs ->
        let b = Buffer.create 30 in
        for _ = 0 to 2 do
          Buffer.add_string b (msgs ())
        done;
        Buffer.contents b);
    server_stream_rpc serverStreamingEcho' (fun msg rcps ->
        String.iter (fun c -> rcps (String.make 1 c)) msg);
    bidirectional_stream_rpc bidirectionalStreamingEcho' (fun msgs rcps ->
        for _ = 0 to 2 do
          rcps (msgs ())
        done);
  ]

let serve () =
  let c = Server.wait_call ~timeout:5L server in
  print_endline c.method_;
  GRPC_protoc_plugin.Server.serve c services

let () = serve ()

let () = serve ()

let () = serve ()

let () = serve ()

let () = Server.destroy server
