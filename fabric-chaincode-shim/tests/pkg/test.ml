open FabricChaincodeShim

let target = if Array.length Sys.argv > 1 then Sys.argv.(1) else "unix:socket"

let id_name = if Array.length Sys.argv > 2 then Sys.argv.(2) else "mycc:1.0"
      
let query stub arg =
  let payload = getState stub arg in
  Response.success ~payload ()

let put stub key value =
  putState stub ~key ~value;
  Response.success ()

let () =
  loop ~id_name ~target
    ~init:(fun stub ->
        Printf.eprintf "init@.";
      let _, args = getFunctionAndParams stub in
      let rec aux = function
        | name::value::l -> ignore (put stub name value); aux l
        | [] -> Response.success ()
        | [s] -> Response.error ~message:(Printf.sprintf "spurious initial argument:%s" s) ()
      in
      aux args)
    ~invoke:(fun stub ->
      let fname, args = getFunctionAndParams stub in
      match (fname, args) with
      | "query", [ a ] -> query stub a
      | "put", [ a; v ] -> put stub a v
      | _ -> Response.error ~message:"Unknown function" ())
