open Ctypes

module Types (F : Ctypes.TYPE) = struct
  open F

  let typedef_structure name = typedef (structure name) name

  type grpc_channel_args

  let grpc_channel_args : grpc_channel_args structure typ =
    typedef_structure "grpc_channel_args"

  type grpc_server

  let grpc_server : grpc_server structure typ = typedef_structure "grpc_server"

  type grpc_call

  let grpc_call : grpc_call structure typ = typedef_structure "grpc_call"

  type grpc_completion_queue

  let grpc_completion_queue : grpc_completion_queue structure typ =
    typedef_structure "grpc_completion_queue"

  module GPR_clock_type = struct
    type t =
      | GPR_CLOCK_MONOTONIC
      | GPR_CLOCK_REALTIME
      | GPR_CLOCK_PRECISE
      | GPR_TIMESPAN

    let t =
      enum ~typedef:true "gpr_clock_type"
        [
          (GPR_CLOCK_MONOTONIC, constant "GPR_CLOCK_MONOTONIC" int64_t);
          (GPR_CLOCK_REALTIME, constant "GPR_CLOCK_REALTIME" int64_t);
          (GPR_CLOCK_PRECISE, constant "GPR_CLOCK_PRECISE" int64_t);
          (GPR_TIMESPAN, constant "GPR_TIMESPAN" int64_t);
        ]
  end

  module GPR_timespec = struct
    type t

    let t : t structure typ = typedef_structure "gpr_timespec"

    let tv_sec = field t "tv_sec" int64_t

    let tv_nsec = field t "tv_nsec" int32_t

    let clock_type = field t "clock_type" GPR_clock_type.t

    let () = seal t
  end

  module GRPC_completion_type = struct
    type t = GRPC_QUEUE_SHUTDOWN | GRPC_QUEUE_TIMEOUT | GRPC_OP_COMPLETE

    let t =
      enum ~typedef:true "grpc_completion_type"
        [
          (GRPC_QUEUE_SHUTDOWN, constant "GRPC_QUEUE_SHUTDOWN" int64_t);
          (GRPC_QUEUE_TIMEOUT, constant "GRPC_QUEUE_TIMEOUT" int64_t);
          (GRPC_OP_COMPLETE, constant "GRPC_OP_COMPLETE" int64_t);
        ]
  end

  module GRPC_event = struct
    type t

    let t : t structure typ = typedef_structure "grpc_event"

    let type_ = field t "type" GRPC_completion_type.t

    let success = field t "success" int

    let tag = field t "tag" (ptr void)

    let () = seal t
  end

  module GRPC_server_register_method_payload_handling = struct
    type t = GRPC_SRM_PAYLOAD_NONE | GRPC_SRM_PAYLOAD_READ_INITIAL_BYTE_BUFFER

    let t =
      enum ~typedef:true "grpc_server_register_method_payload_handling"
        [
          (GRPC_SRM_PAYLOAD_NONE, constant "GRPC_SRM_PAYLOAD_NONE" int64_t);
          ( GRPC_SRM_PAYLOAD_READ_INITIAL_BYTE_BUFFER,
            constant "GRPC_SRM_PAYLOAD_READ_INITIAL_BYTE_BUFFER" int64_t );
        ]
  end

  module GRPC_call_error = struct
    type t =
      | GRPC_CALL_OK
      | GRPC_CALL_ERROR
      | GRPC_CALL_ERROR_NOT_ON_SERVER
      | GRPC_CALL_ERROR_NOT_ON_CLIENT
      | GRPC_CALL_ERROR_ALREADY_ACCEPTED
      | GRPC_CALL_ERROR_ALREADY_INVOKED
      | GRPC_CALL_ERROR_NOT_INVOKED
      | GRPC_CALL_ERROR_ALREADY_FINISHED
      | GRPC_CALL_ERROR_TOO_MANY_OPERATIONS
      | GRPC_CALL_ERROR_INVALID_FLAGS
      | GRPC_CALL_ERROR_INVALID_METADATA
      | GRPC_CALL_ERROR_INVALID_MESSAGE
      | GRPC_CALL_ERROR_NOT_SERVER_COMPLETION_QUEUE
      | GRPC_CALL_ERROR_BATCH_TOO_BIG
      | GRPC_CALL_ERROR_PAYLOAD_TYPE_MISMATCH
      | GRPC_CALL_ERROR_COMPLETION_QUEUE_SHUTDOWN

    let t =
      enum ~typedef:true "grpc_call_error"
        [
          (GRPC_CALL_OK, constant "GRPC_CALL_OK" int64_t);
          (GRPC_CALL_ERROR, constant "GRPC_CALL_ERROR" int64_t);
          ( GRPC_CALL_ERROR_NOT_ON_SERVER,
            constant "GRPC_CALL_ERROR_NOT_ON_SERVER" int64_t );
          ( GRPC_CALL_ERROR_NOT_ON_CLIENT,
            constant "GRPC_CALL_ERROR_NOT_ON_CLIENT" int64_t );
          ( GRPC_CALL_ERROR_ALREADY_ACCEPTED,
            constant "GRPC_CALL_ERROR_ALREADY_ACCEPTED" int64_t );
          ( GRPC_CALL_ERROR_ALREADY_INVOKED,
            constant "GRPC_CALL_ERROR_ALREADY_INVOKED" int64_t );
          ( GRPC_CALL_ERROR_NOT_INVOKED,
            constant "GRPC_CALL_ERROR_NOT_INVOKED" int64_t );
          ( GRPC_CALL_ERROR_ALREADY_FINISHED,
            constant "GRPC_CALL_ERROR_ALREADY_FINISHED" int64_t );
          ( GRPC_CALL_ERROR_TOO_MANY_OPERATIONS,
            constant "GRPC_CALL_ERROR_TOO_MANY_OPERATIONS" int64_t );
          ( GRPC_CALL_ERROR_INVALID_FLAGS,
            constant "GRPC_CALL_ERROR_INVALID_FLAGS" int64_t );
          ( GRPC_CALL_ERROR_INVALID_METADATA,
            constant "GRPC_CALL_ERROR_INVALID_METADATA" int64_t );
          ( GRPC_CALL_ERROR_INVALID_MESSAGE,
            constant "GRPC_CALL_ERROR_INVALID_MESSAGE" int64_t );
          ( GRPC_CALL_ERROR_NOT_SERVER_COMPLETION_QUEUE,
            constant "GRPC_CALL_ERROR_NOT_SERVER_COMPLETION_QUEUE" int64_t );
          ( GRPC_CALL_ERROR_BATCH_TOO_BIG,
            constant "GRPC_CALL_ERROR_BATCH_TOO_BIG" int64_t );
          ( GRPC_CALL_ERROR_PAYLOAD_TYPE_MISMATCH,
            constant "GRPC_CALL_ERROR_PAYLOAD_TYPE_MISMATCH" int64_t );
          ( GRPC_CALL_ERROR_COMPLETION_QUEUE_SHUTDOWN,
            constant "GRPC_CALL_ERROR_COMPLETION_QUEUE_SHUTDOWN" int64_t );
        ]
  end

  module GRPC_slice = struct
    type t

    let t : t structure typ = typedef_structure "grpc_slice"

    let () = seal t
  end

  module GRPC_metadata = struct
    type t

    let t : t structure typ = typedef_structure "grpc_metadata"

    let key = field t "key" GRPC_slice.t

    let value = field t "value" GRPC_slice.t

    let () = seal t
  end

  module GRPC_metadata_array = struct
    type t

    let t : t structure typ = typedef_structure "grpc_metadata_array"

    let count = field t "count" size_t

    let capacity = field t "capacity" size_t

    let metadata = field t "metadata" (ptr GRPC_metadata.t)

    let () = seal t
  end

  module GRPC_call_details = struct
    type t

    let t : t structure typ = typedef_structure "grpc_call_details"

    let method_ = field t "method" GRPC_slice.t

    let host = field t "host" GRPC_slice.t

    let deadline = field t "deadline" GPR_timespec.t

    let flags = field t "flags" uint32_t

    let () = seal t
  end
end
