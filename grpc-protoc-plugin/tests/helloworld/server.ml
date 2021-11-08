open GRPC

let server = Server.create ~listening:"unix:socket" ()

let () =
  let c = Server.wait_call ~timeout:5L server in
  assert (c.method_ = "sayHello");
  GRPC_protoc_plugin.Server.simple_rpc c Helloworld.Helloworld.Greeter.sayHello
    (fun name -> Printf.sprintf "Hello %s, nice to meet you" name)

let () = Server.destroy server
