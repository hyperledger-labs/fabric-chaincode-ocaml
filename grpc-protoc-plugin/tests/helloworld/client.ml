open GRPC

let client = Client.create ~target:"unix:socket" ()

let () =
  let rsp =
    GRPC_protoc_plugin.Client.simple_rpc ~meth:"sayHello" ~timeout:4L client
      Helloworld.Helloworld.Greeter.sayHello "Client"
  in
  print_endline rsp

let () = Client.destroy client
