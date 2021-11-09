open GRPC

let listening =
  if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"

let server = Server.create ~listening ()

let () =
  let c = Server.wait_call ~timeout:5L server in
  print_endline c.method_;
  GRPC_protoc_plugin.Server.(
    serve c
      [
        unary_rpc Helloworld.Helloworld.Greeter.sayHello' (fun name ->
            Printf.sprintf "Hello %s" name);
      ])

let () = Server.destroy server
