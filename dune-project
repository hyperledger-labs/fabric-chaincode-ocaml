(lang dune 3.0)

(generate_opam_files true)
(using ctypes 0.1)

(authors "François Bobot")


(package
 (name fabric-chaincode-shim)
 (depends ocaml-protoc-plugin
          ppx_deriving
          libgrpc
          conf-protoc
          )
 (synopsis "Shim for implementing Hypeledger Fabric chaincode in OCaml")
)

 (package
 (name grpc)
 (depends ctypes)
 (synopsis "Binding to libgrpc core")
)

(package
 (name grpc-protoc-plugin)
 (depends ctypes grpc ocaml-protoc-plugin)
 (synopsis "GRPC services using ocaml-protoc-plugin definitions")
)
