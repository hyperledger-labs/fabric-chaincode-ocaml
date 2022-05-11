(lang dune 3.0)

(generate_opam_files true)
(using ctypes 0.1)

(authors "François Bobot")
(maintainers "François Bobot")
(source (github bobot/fabric-chaincode-ocaml))

(package
 (name fabric-chaincode-shim)
 (depends ocaml-protoc-plugin
          ppx_deriving
          conf-protoc
          grpc
          grpc-protoc-plugin
          )
 (synopsis "Shim for implementing Hypeledger Fabric chaincode in OCaml")
)

 (package
 (name grpc)
 (depends ctypes memcpy dune-configurator conf-pkg-config)
 (synopsis "Binding to libgrpc core")
)

(package
 (name grpc-protoc-plugin)
 (depends ctypes grpc ocaml-protoc-plugin)
 (synopsis "GRPC services using ocaml-protoc-plugin definitions")
)

(package
 (name conf-libgrpc)
 (allow_empty)
)
