open Protobuf

module Response = struct
  type t = Proposal_response.Response.t [@@deriving show, eq]

  let success ?payload () : t =
    Proposal_response.Response.make ~status:200 ?payload ()

  let error ?message () : t =
    Proposal_response.Response.make ~status:400 ?message ()
end

type stub = {
  payload : string;
  from_server : unit -> Chaincode_shim.ChaincodeMessage.t;
  to_server : Chaincode_shim.ChaincodeMessage.t -> unit;
  txid : string;
  channel_id : string;
}

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

let getState stub key =
  let payload =
    Chaincode_shim.GetState.make ~key ()
    |> Chaincode_shim.GetState.to_proto |> Ocaml_protoc_plugin.Writer.contents
  in
  let msg =
    Chaincode_shim.ChaincodeMessage.make ~type':GET_STATE ~payload
      ~txid:stub.txid ~channel_id:stub.channel_id ()
  in
  stub.to_server msg;
  Format.printf "GetState %s@." key;
  let rcp = stub.from_server () in
  Format.printf "Message received %a@." Chaincode_shim.ChaincodeMessage.pp rcp;
  assert (rcp.type' = Chaincode_shim.ChaincodeMessage.Type.RESPONSE);
  assert (rcp.txid = stub.txid);
  assert (rcp.channel_id = stub.channel_id);
  rcp.payload

let putState stub ~key ~value =
  let payload =
    Chaincode_shim.PutState.make ~key ~value ()
    |> Chaincode_shim.PutState.to_proto |> Ocaml_protoc_plugin.Writer.contents
  in
  let msg =
    Chaincode_shim.ChaincodeMessage.make ~type':PUT_STATE ~payload
      ~txid:stub.txid ~channel_id:stub.channel_id ()
  in
  stub.to_server msg;
  Format.printf "PutState %s<-%s@." key value;
  let rcp = stub.from_server () in
  Format.printf "Message received %a@." Chaincode_shim.ChaincodeMessage.pp rcp;
  assert (rcp.type' = Chaincode_shim.ChaincodeMessage.Type.RESPONSE);
  assert (rcp.txid = stub.txid);
  assert (rcp.channel_id = stub.channel_id);
  assert (rcp.payload = "")

let mk_stub ~txid ~channel_id from_server to_server msg =
  {
    payload = msg.Chaincode_shim.ChaincodeMessage.payload;
    from_server;
    to_server;
    txid;
    channel_id;
  }

let call rcps msgs (rcp : Chaincode_shim.ChaincodeMessage.t) f =
  let stub = mk_stub ~txid:rcp.txid ~channel_id:rcp.channel_id rcps msgs rcp in
  let response = f stub in
  let payload =
    response |> Proposal_response.Response.to_proto
    |> Ocaml_protoc_plugin.Writer.contents
  in
  msgs
    (Chaincode_shim.ChaincodeMessage.make ~type':COMPLETED ~payload
       ~txid:rcp.txid ~channel_id:rcp.channel_id ())

let loop ~id_name ~target ~init ~invoke =
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
        | INIT ->
            Format.printf "msg:Init: %a@." ChaincodeMessage.pp rcp;
            call rcps msgs rcp init
        | READY -> Format.printf "msg:Register@."
        | TRANSACTION ->
            Format.printf "msg:Transaction@.";
            call rcps msgs rcp invoke
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
