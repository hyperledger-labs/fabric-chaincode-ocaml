open Protobuf

module Response = struct
  type t = Proposal_response.Response.t [@@deriving show, eq]

  let success ?payload () : t =
    Proposal_response.Response.make ~status:200 ?payload ()

  let error ?message () : t =
    Proposal_response.Response.make ~status:400 ?message ()
end

type stub = { payload : string }

let getFunctionAndParams stub =
  match
    Chaincode.ChaincodeInput.from_proto
      (Ocaml_protoc_plugin.Reader.create stub.payload)
  with
  | Ok { args = func :: params; _ } -> (func, params)
  | Ok { args = []; _ } -> invalid_arg "No function name given"
  | Error s ->
      invalid_arg
        ("FunctionAndParams: " ^ Ocaml_protoc_plugin.Result.show_error s)

let mk_stub msg = { payload = msg.Chaincode_shim.ChaincodeMessage.payload }

let loop ~id_name ~target ~init:_ ~invoke =
  let client = GRPC.Client.create ~target () in
  Format.printf "Call@.";
  GRPC_protoc_plugin.Client.bidirectional_rpc client
    Chaincode_shim.ChaincodeSupport.register' (fun msgs rcps ->
      let rec loop () =
        Format.printf "loop@.";
        let rcp = rcps () in
        let open Chaincode_shim in
        (match rcp.type' with
        | REGISTER ->
            Format.printf "msg:Register received by client!@.";
            assert false
        | REGISTERED -> Format.printf "msg:Register@."
        | INIT -> Format.printf "msg:Init: %a@." ChaincodeMessage.pp rcp
        | READY -> Format.printf "msg:Register@."
        | TRANSACTION ->
            Format.printf "msg:Transaction@.";
            let stub = mk_stub rcp in
            let response = invoke stub in
            let payload =
              response |> Proposal_response.Response.to_proto
              |> Ocaml_protoc_plugin.Writer.contents
            in
            msgs
              (Chaincode_shim.ChaincodeMessage.make ~type':COMPLETED ~payload
                 ~txid:rcp.txid ~channel_id:rcp.channel_id ())
        | UNDEFINED | COMPLETED | ERROR | GET_STATE | PUT_STATE | DEL_STATE
        | INVOKE_CHAINCODE | RESPONSE | GET_STATE_BY_RANGE | GET_QUERY_RESULT
        | QUERY_STATE_NEXT | QUERY_STATE_CLOSE | KEEPALIVE | GET_HISTORY_FOR_KEY
        | GET_STATE_METADATA | PUT_STATE_METADATA | GET_PRIVATE_DATA_HASH ->
            Format.printf "msg:%a@." ChaincodeMessage.pp rcp);
        loop ()
      in
      Format.printf "Register@.";
      let payload =
        Chaincode.ChaincodeID.make ~name:id_name ()
        |> Chaincode.ChaincodeID.to_proto |> Ocaml_protoc_plugin.Writer.contents
      in
      msgs (Chaincode_shim.ChaincodeMessage.make ~type':REGISTER ~payload ());
      loop ())
