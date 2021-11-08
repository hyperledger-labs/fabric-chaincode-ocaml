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

  type grpc_channel

  let grpc_channel : grpc_channel structure typ =
    typedef_structure "grpc_channel"

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

  module GRPC_slice_buffer = struct
    type t

    let t : t structure typ = typedef_structure "grpc_slice_buffer"

    let slices = field t "slices" (ptr GRPC_slice.t)

    let count = field t "count" size_t

    let length = field t "length" size_t

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

  module GRPC_op_type = struct
    type t =
      | GRPC_OP_SEND_INITIAL_METADATA
      | GRPC_OP_SEND_MESSAGE
      | GRPC_OP_SEND_CLOSE_FROM_CLIENT
      | GRPC_OP_SEND_STATUS_FROM_SERVER
      | GRPC_OP_RECV_INITIAL_METADATA
      | GRPC_OP_RECV_MESSAGE
      | GRPC_OP_RECV_STATUS_ON_CLIENT
      | GRPC_OP_RECV_CLOSE_ON_SERVER

    let t =
      enum ~typedef:true "grpc_op_type"
        [
          ( GRPC_OP_SEND_INITIAL_METADATA,
            constant "GRPC_OP_SEND_INITIAL_METADATA" int64_t );
          (GRPC_OP_SEND_MESSAGE, constant "GRPC_OP_SEND_MESSAGE" int64_t);
          ( GRPC_OP_SEND_CLOSE_FROM_CLIENT,
            constant "GRPC_OP_SEND_CLOSE_FROM_CLIENT" int64_t );
          ( GRPC_OP_SEND_STATUS_FROM_SERVER,
            constant "GRPC_OP_SEND_STATUS_FROM_SERVER" int64_t );
          ( GRPC_OP_RECV_INITIAL_METADATA,
            constant "GRPC_OP_RECV_INITIAL_METADATA" int64_t );
          (GRPC_OP_RECV_MESSAGE, constant "GRPC_OP_RECV_MESSAGE" int64_t);
          ( GRPC_OP_RECV_STATUS_ON_CLIENT,
            constant "GRPC_OP_RECV_STATUS_ON_CLIENT" int64_t );
          ( GRPC_OP_RECV_CLOSE_ON_SERVER,
            constant "GRPC_OP_RECV_CLOSE_ON_SERVER" int64_t );
        ]
  end

  module GRPC_compression_level = struct
    type t =
      | GRPC_COMPRESS_LEVEL_NONE
      | GRPC_COMPRESS_LEVEL_LOW
      | GRPC_COMPRESS_LEVEL_MED
      | GRPC_COMPRESS_LEVEL_HIGH
      | GRPC_COMPRESS_LEVEL_COUNT

    let t =
      enum ~typedef:true "grpc_compression_level"
        [
          (GRPC_COMPRESS_LEVEL_NONE, constant "GRPC_COMPRESS_LEVEL_NONE" int64_t);
          (GRPC_COMPRESS_LEVEL_LOW, constant "GRPC_COMPRESS_LEVEL_LOW" int64_t);
          (GRPC_COMPRESS_LEVEL_MED, constant "GRPC_COMPRESS_LEVEL_MED" int64_t);
          (GRPC_COMPRESS_LEVEL_HIGH, constant "GRPC_COMPRESS_LEVEL_HIGH" int64_t);
          ( GRPC_COMPRESS_LEVEL_COUNT,
            constant "GRPC_COMPRESS_LEVEL_COUNT" int64_t );
        ]
  end

  module GRPC_compression_algorithm = struct
    type t =
      | GRPC_COMPRESS_NONE
      | GRPC_COMPRESS_DEFLATE
      | GRPC_COMPRESS_GZIP
      | GRPC_COMPRESS_STREAM_GZIP
      | GRPC_COMPRESS_ALGORITHMS_COUNT

    let t =
      enum "grpc_compression_algorithm" ~typedef:true
        [
          (GRPC_COMPRESS_NONE, constant "GRPC_COMPRESS_NONE" int64_t);
          (GRPC_COMPRESS_DEFLATE, constant "GRPC_COMPRESS_DEFLATE" int64_t);
          (GRPC_COMPRESS_GZIP, constant "GRPC_COMPRESS_GZIP" int64_t);
          ( GRPC_COMPRESS_STREAM_GZIP,
            constant "GRPC_COMPRESS_STREAM_GZIP" int64_t );
          ( GRPC_COMPRESS_ALGORITHMS_COUNT,
            constant "GRPC_COMPRESS_ALGORITHMS_COUNT" int64_t );
        ]
  end

  module GRPC_byte_buffer_type = struct
    type t = GRPC_BB_RAW

    let t =
      enum ~typedef:true "grpc_byte_buffer_type"
        [ (GRPC_BB_RAW, constant "GRPC_BB_RAW" int64_t) ]
  end

  module GRPC_byte_buffer = struct
    type t

    let t : t structure typ = structure "grpc_byte_buffer"

    let type_ = field t "type" GRPC_byte_buffer_type.t

    module Data = struct
      type t

      let t : t union typ = union "grpc_byte_buffer_data"

      module Compressed_buffer = struct
        type t

        let t : t structure typ = structure "grpc_compressed_buffer"

        let compression = field t "compression" GRPC_compression_algorithm.t

        let slice_buffer = field t "slice_buffer" GRPC_slice_buffer.t

        let () = seal t
      end

      let raw = field t "raw" Compressed_buffer.t

      let () = seal t
    end

    let data = field t "data" Data.t

    let () = seal t
  end

  module GRPC_status_code = struct
    type t =
      | GRPC_STATUS_OK
      | GRPC_STATUS_CANCELLED
      | GRPC_STATUS_UNKNOWN
      | GRPC_STATUS_INVALID_ARGUMENT
      | GRPC_STATUS_DEADLINE_EXCEEDED
      | GRPC_STATUS_NOT_FOUND
      | GRPC_STATUS_ALREADY_EXISTS
      | GRPC_STATUS_PERMISSION_DENIED
      | GRPC_STATUS_UNAUTHENTICATED
      | GRPC_STATUS_RESOURCE_EXHAUSTED
      | GRPC_STATUS_FAILED_PRECONDITION
      | GRPC_STATUS_ABORTED
      | GRPC_STATUS_OUT_OF_RANGE
      | GRPC_STATUS_UNIMPLEMENTED
      | GRPC_STATUS_INTERNAL
      | GRPC_STATUS_UNAVAILABLE
      | GRPC_STATUS_DATA_LOSS
      | GRPC_STATUS__DO_NOT_USE

    let t =
      enum "grpc_status_code" ~typedef:true
        [
          (GRPC_STATUS_OK, constant "GRPC_STATUS_OK" int64_t);
          (GRPC_STATUS_CANCELLED, constant "GRPC_STATUS_CANCELLED" int64_t);
          (GRPC_STATUS_UNKNOWN, constant "GRPC_STATUS_UNKNOWN" int64_t);
          ( GRPC_STATUS_INVALID_ARGUMENT,
            constant "GRPC_STATUS_INVALID_ARGUMENT" int64_t );
          ( GRPC_STATUS_DEADLINE_EXCEEDED,
            constant "GRPC_STATUS_DEADLINE_EXCEEDED" int64_t );
          (GRPC_STATUS_NOT_FOUND, constant "GRPC_STATUS_NOT_FOUND" int64_t);
          ( GRPC_STATUS_ALREADY_EXISTS,
            constant "GRPC_STATUS_ALREADY_EXISTS" int64_t );
          ( GRPC_STATUS_PERMISSION_DENIED,
            constant "GRPC_STATUS_PERMISSION_DENIED" int64_t );
          ( GRPC_STATUS_UNAUTHENTICATED,
            constant "GRPC_STATUS_UNAUTHENTICATED" int64_t );
          ( GRPC_STATUS_RESOURCE_EXHAUSTED,
            constant "GRPC_STATUS_RESOURCE_EXHAUSTED" int64_t );
          ( GRPC_STATUS_FAILED_PRECONDITION,
            constant "GRPC_STATUS_FAILED_PRECONDITION" int64_t );
          (GRPC_STATUS_ABORTED, constant "GRPC_STATUS_ABORTED" int64_t);
          (GRPC_STATUS_OUT_OF_RANGE, constant "GRPC_STATUS_OUT_OF_RANGE" int64_t);
          ( GRPC_STATUS_UNIMPLEMENTED,
            constant "GRPC_STATUS_UNIMPLEMENTED" int64_t );
          (GRPC_STATUS_INTERNAL, constant "GRPC_STATUS_INTERNAL" int64_t);
          (GRPC_STATUS_UNAVAILABLE, constant "GRPC_STATUS_UNAVAILABLE" int64_t);
          (GRPC_STATUS_DATA_LOSS, constant "GRPC_STATUS_DATA_LOSS" int64_t);
          (GRPC_STATUS__DO_NOT_USE, constant "GRPC_STATUS__DO_NOT_USE" int64_t);
        ]
  end

  module GRPC_op = struct
    type t

    let t : t structure typ = typedef_structure "grpc_op"

    let op = field t "op" GRPC_op_type.t

    let flags = field t "flags" uint32_t

    module Data = struct
      type t

      let t : t union typ = union "grpc_op_data"

      module Send_initial_metadata = struct
        type t

        let t : t structure typ = structure "grpc_op_send_initial_metadata"

        let count = field t "count" size_t

        let metadata = field t "metadata" (ptr GRPC_metadata.t)

        module Maybe_compression_level = struct
          type t

          let t : t structure typ =
            structure "grpc_op_send_initial_metadata_maybe_compression_level"

          let is_set = field t "is_set" uint8_t

          let level = field t "level" GRPC_compression_level.t

          let () = seal t
        end

        let maybe_compression_level =
          field t "maybe_compression_level" Maybe_compression_level.t

        let () = seal t
      end

      let send_initial_metadata =
        field t "send_initial_metadata" Send_initial_metadata.t

      module Send_message = struct
        type t

        let t : t structure typ = structure "grpc_op_send_message"

        let send_message = field t "send_message" (ptr GRPC_byte_buffer.t)

        let () = seal t
      end

      let send_message = field t "send_message" Send_message.t

      module Send_status_from_server = struct
        type t

        let t : t structure typ = structure "grpc_op_send_status_from_server"

        let trailing_metadata_count = field t "trailing_metadata_count" size_t

        let trailing_metadata =
          field t "trailing_metadata" (ptr GRPC_metadata.t)

        let status = field t "status" GRPC_status_code.t

        let status_detals = field t "status_details" (ptr_opt GRPC_slice.t)

        let () = seal t
      end

      let send_status_from_server =
        field t "send_status_from_server" Send_status_from_server.t

      module Recv_initial_metadata = struct
        type t

        let t : t structure typ = structure "grpc_op_recv_initial_metadata"

        let recv_initial_metadata =
          field t "recv_initial_metadata" (ptr GRPC_metadata_array.t)

        let () = seal t
      end

      let recv_initial_metadata =
        field t "recv_initial_metadata" Recv_initial_metadata.t

      module Recv_message = struct
        type t

        let t : t structure typ = structure "grpc_op_recv_message"

        let recv_message = field t "recv_message" (ptr (ptr GRPC_byte_buffer.t))

        let () = seal t
      end

      let recv_message = field t "recv_message" Recv_message.t

      module Recv_status_on_client = struct
        type t

        let t : t structure typ = structure "grpc_op_recv_status_on_client"

        let trailing_metadata =
          field t "trailing_metadata" (ptr GRPC_metadata_array.t)

        let status = field t "status" (ptr GRPC_status_code.t)

        let status_details = field t "status_details" (ptr GRPC_slice.t)

        let error_string = field t "error_string" (ptr_opt (ptr char))

        let () = seal t
      end

      let recv_status_on_client =
        field t "recv_status_on_client" Recv_status_on_client.t

      module Recv_close_on_server = struct
        type t

        let t : t structure typ = structure "grpc_op_recv_close_on_server"

        let cancelled = field t "cancelled" (ptr int)

        let () = seal t
      end

      let recv_close_on_server =
        field t "recv_close_on_server" Recv_close_on_server.t

      let () = seal t
    end

    let data = field t "data" Data.t

    let () = seal t
  end

  module GRPC_propagate_bits = struct
    let default = constant "GRPC_PROPAGATE_DEFAULTS" uint32_t

    let deadline = constant "GRPC_PROPAGATE_DEADLINE" uint32_t

    let census_stats_context =
      constant "GRPC_PROPAGATE_CENSUS_STATS_CONTEXT" uint32_t

    let grpc_propagate_census_tracing_context =
      constant "GRPC_PROPAGATE_CENSUS_TRACING_CONTEXT" uint32_t

    let grpc_propagate_cancellation =
      constant "GRPC_PROPAGATE_CANCELLATION" uint32_t
  end
end
