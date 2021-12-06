#include <grpc/grpc.h>
#include <grpc/slice.h>
#include <ctypes_raw_pointer.h>

/* The stub generated use an intermediate grpc_slice which gives a local pointer
   in the case of inline slice */
value grpc_stubs_wrap_GRPC_SLICE_START_PTR(value x60)
{
   void* x61 = CTYPES_ADDR_OF_FATPTR(x60);
   char* x64 = GRPC_SLICE_START_PTR(*(grpc_slice*)x61);
   return CTYPES_FROM_PTR(x64);
}

/* static inline grpc_slice SliceVal(value v){ */
/*   return (grpc_slice)Data_custom_val(v); */
/* } */

/* static void unref_slice(value v) */
/* { */
/*   grpc_slice_unref(Slive_val(v)); */
/* } */

/* static int compare_slice(value l, value r) */
/* { */
/*   return grpc_slice_cmp(SliceVal(l),SliceVal(r)); */
/* } */

/* static intnat hash_slice(value l) */
/* { */
/*   /\* address hashing *\/ */
/*   return grpc_slice_hash(SliceVal(l)); */
/* } */

/* static struct custom_operations slice_custom_ops = { */
/*   "grpc:slice", */
/*   unref_slice, */
/*   compare_slice, */
/*   hash_slice, */
/*   /\* slice are not serializable. *\/ */
/*   custom_serialize_default, */
/*   custom_deserialize_default, */
/*   custom_compare_ext_default */
/* }; */

/* value caml_grpc_copy_slice(grpc_slice slice){ */
/*   CAMLparam0(); */
/*   CAMLlocal1(block); */
/*   block = caml_alloc_custom(&slice_custom_ops, sizeof(grpc_slice), 0, 1); */
/*   memcpy(&Data_custom_val(block),&slice,sizeof(grpc_slice)); */
/*   CAMLreturn(block); */
/* } */
