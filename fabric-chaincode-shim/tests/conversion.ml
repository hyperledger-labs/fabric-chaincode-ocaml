let () =
  let timestamp = FabricChaincodeShim.Protobuf.Timestamp.make ~seconds:42 () in
  Printf.printf "%i\n" timestamp.seconds;
  let encoded =
    FabricChaincodeShim.Protobuf.Timestamp.to_proto timestamp
    |> Ocaml_protoc_plugin.Writer.contents
  in
  Printf.printf "%S\n" encoded;
  let decoded =
    Ocaml_protoc_plugin.Reader.create encoded
    |> FabricChaincodeShim.Protobuf.Timestamp.from_proto |> Result.get_ok
  in
  Printf.printf "%i\n" decoded.seconds
