let target = if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"

let () =
  let open FabricChaincodeShim in
  loop ~id_name:"mycc:1.0" ~target
    ~init:(fun _ -> assert false)
    ~invoke:(fun stub ->
      let fname, _args = getFunctionAndParams stub in
      match fname with
      | "query" -> Response.success ~payload:"42" ()
      | _ -> Response.error ~message:"Unknown function" ())
