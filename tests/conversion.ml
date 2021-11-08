let () =
  let timestamp =
    FabricChaincodeShim.Timestamp.Google.Protobuf.Timestamp.make ~seconds:42 ()
  in
  Printf.printf "%i\n" timestamp.seconds;
  let encoded =
    FabricChaincodeShim.Timestamp.Google.Protobuf.Timestamp.to_proto timestamp
    |> Ocaml_protoc_plugin.Writer.contents
  in
  Printf.printf "%S\n" encoded;
  let decoded =
    Ocaml_protoc_plugin.Reader.create encoded
    |> FabricChaincodeShim.Timestamp.Google.Protobuf.Timestamp.from_proto
    |> Result.get_ok
  in
  Printf.printf "%i\n" decoded.seconds
