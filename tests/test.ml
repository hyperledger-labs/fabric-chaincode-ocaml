open FabricChaincodeShim

let target = if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"

let query stub arg =
  let payload = getState stub arg in
  Response.success ~payload ()

let put stub key value =
  putState stub ~key ~value;
  Response.success ()

let () =
  loop ~id_name:"mycc:1.0" ~target
    ~init:(fun _ -> Response.success ())
    ~invoke:(fun stub ->
      let fname, args = getFunctionAndParams stub in
      match (fname, args) with
      | "query", [ a ] -> query stub a
      | "put", [ a; v ] -> put stub a v
      | _ -> Response.error ~message:"Unknown function" ())
