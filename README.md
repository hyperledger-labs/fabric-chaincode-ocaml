# fabric-chaincode-ocaml
OCaml support for smart contracts in Hyperledger Fabric

The repository contains three OCaml packages:
  * grpc: OCaml binding to libgrpc core
  * grpc-protoc-plugin: link between services defined by
    [ocaml-protoc-plugin](https://github.com/issuu/ocaml-protoc-plugin) and the
    grpc library. Instantiate server and client of grpc with the definition
    derived from a protobuf file by ocaml-protoc-plugin
  * fabric-chaincode-shim: define the actual shim for defining chaincode for
    Hyperledger Fabric, using grpc-protoc-plugin and the protobuf file of
    Hyperledger Fabric.


A specific version of ocaml-protoc-plugin is currently used. It is specified
using a submodule.

# Installation in development mode

    The repository uses unreleased features of dune 3.0, in order to install it:

```
opam pin "https://github.com/ocaml/dune.git" --with-version=3.0
```

    The installation of the different dependencies is done in the repository using opam 2.1 with:

```
git clone https://github.com/bobot/fabric-chaincode-ocaml.git
cd fabric-chaincode-ocaml
opam install --deps-only .
```
