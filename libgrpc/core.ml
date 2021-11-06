include C.Type
include C.Function
module CI = Cstubs_internals

external grpc_stubs_wrap_GRPC_SLICE_START_PTR : _ CI.fatptr -> CI.voidp
  = "grpc_stubs_wrap_GRPC_SLICE_START_PTR"

let grpc_slice_start_ptr x15 =
  let (CI.CPointer x18) = Ctypes.addr x15 in
  let x17 = x18 in
  CI.make_ptr Ctypes.char (grpc_stubs_wrap_GRPC_SLICE_START_PTR x17)

let string_of_slice s =
  let p = grpc_slice_start_ptr s in
  let length = grpc_slice_length s in
  let length = Unsigned.Size_t.to_int length in
  Ctypes.string_from_ptr p ~length

let slice_of_string s =
  let ptr = Ctypes.ocaml_string_start s in
  let len = Unsigned.Size_t.of_int @@ String.length s in
  grpc_slice_from_copied_buffer ptr len
