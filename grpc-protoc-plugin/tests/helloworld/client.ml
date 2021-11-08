open GRPC

let target = if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"

let client = Client.create ~target ()

let () =
  let rsp =
    GRPC_protoc_plugin.Client.simple_rpc ~timeout:4L client
      Helloworld.Helloworld.Greeter.sayHello' "Client"
  in
  print_endline rsp

let () = Client.destroy client
