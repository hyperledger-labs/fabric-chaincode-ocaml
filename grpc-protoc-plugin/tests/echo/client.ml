open GRPC

let target = if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"
let client = Client.create ~target ()

let () =
  print_endline "Unary";
  let rsp =
    GRPC_protoc_plugin.Client.unary_rpc ~timeout:4L client
      Echo.Grpc.Examples.Echo.Echo.unaryEcho' "Client"
  in
  print_endline rsp

let () =
  print_endline "Client Stream";
  let rsp =
    GRPC_protoc_plugin.Client.client_stream_rpc ~timeout:4L client
      Echo.Grpc.Examples.Echo.Echo.clientStreamingEcho' (fun msgs ->
        List.iter msgs [ "Client"; "Customer"; "Me" ])
  in
  print_endline rsp

let () =
  print_endline "Server Stream";
  let (), _ =
    GRPC_protoc_plugin.Client.server_stream_rpc ~timeout:4L client
      Echo.Grpc.Examples.Echo.Echo.serverStreamingEcho' "Client" (fun rcps ->
        for _ = 0 to 5 do
          print_endline (Option.value ~default:"None" (rcps ()))
        done)
  in
  ()

let () =
  print_endline "Bidirectional";
  let (), _ =
    GRPC_protoc_plugin.Client.bidirectional_rpc ~timeout:4L client
      Echo.Grpc.Examples.Echo.Echo.bidirectionalStreamingEcho' (fun msgs rcps ->
        List.iter msgs [ "Client"; "Customer"; "Me" ];
        for _ = 0 to 2 do
          print_endline (Option.value ~default:"None" (rcps ()))
        done)
  in
  ()

let () = Client.destroy client
