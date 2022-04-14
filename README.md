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

The installation of the different dependencies is done in the repository using opam 2.1 with:

```
git clone https://github.com/bobot/fabric-chaincode-ocaml.git
cd fabric-chaincode-ocaml
opam install --deps-only .
```

## Hyperledger Fabric Development mode

The script `./fabric-chaincode-shim/tests/peer-chaincode-devmode.sh TMPDIR`
start a shell after starting an hyperledger fabric in development mode. Don't
forget to remove the temporary directory before restarting it. then inside the
new shell a test using the OCaml shim can be started with:

```
dune exec -- fabric-chaincode-shim/tests/test.exe 127.0.0.1:7052 &
CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n mycc -c '{"Args":["query","a"]}'
```
