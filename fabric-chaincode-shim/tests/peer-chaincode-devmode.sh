#!/bin/bash -exu

# From https://github.com/hyperledger/fabric docs/source/peer-chaincode-devmode.md

trap "exit" INT TERM
trap "kill 0" EXIT

ORIGDIR=$PWD

DESTDIR=$1

mkdir $1

cd $1

# 1 -- Clone
git clone https://github.com/hyperledger/fabric --branch release-2.3 --depth=1
cd fabric

# Additional change configuration
sed -i sampleconfig/core.yaml sampleconfig/orderer.yaml -e "s&/var/hyperledger/production&$PWD/../tmp/&g"
sed -i sampleconfig/core.yaml -e "s&127.0.0.1:9443&127.0.0.1:9447&g"
sed -i sampleconfig/core.yaml -e "s&0.0.0.0:7051&127.0.0.1:7051&g"

# 2 -- Build
make orderer peer configtxgen

# 3 -- PATH
export PATH=$(pwd)/build/bin:$PATH

# 4 -- Set config path
export FABRIC_CFG_PATH=$(pwd)/sampleconfig

# 5 -- Genesis block
configtxgen -profile SampleDevModeSolo -channelID syschannel -outputBlock genesisblock -configPath $FABRIC_CFG_PATH -outputBlock $(pwd)/sampleconfig/genesisblock

# 6 -- Start orderer
ORDERER_GENERAL_GENESISPROFILE=SampleDevModeSolo orderer >& orderer.log &

timeout 2 tail -f orderer.log || true

# 7 -- Start peer

FABRIC_LOGGING_SPEC=chaincode=debug CORE_PEER_CHAINCODELISTENADDRESS=127.0.0.1:7052 peer node start --peer-chaincodedev=true >& peer.log &

timeout 5 tail -f peer.log || true

# 8 -- Create channel ch1
configtxgen -channelID ch1 -outputCreateChannelTx ch1.tx -profile SampleSingleMSPChannel -configPath $FABRIC_CFG_PATH
peer channel create -o 127.0.0.1:7050 -c ch1 -f ch1.tx

peer channel join -b ch1.block


# 9 -- Build chaincode
go build -o simpleChaincode ./integration/chaincode/simple/cmd

# 10 -- Start chaincode
CORE_CHAINCODE_LOGLEVEL=debug CORE_PEER_TLS_ENABLED=false CORE_CHAINCODE_ID_NAME=mycc:1.0 ./simpleChaincode -peer.address 127.0.0.1:7052 >& chaincode.log &

timeout 10 tail -f peer.log chaincode.log orderer.log || true

# 11 -- Approve and commit the chaincode definition

peer lifecycle chaincode approveformyorg  -o 127.0.0.1:7050 --channelID ch1 --name mycc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')" --package-id mycc:1.0
peer lifecycle chaincode checkcommitreadiness -o 127.0.0.1:7050 --channelID ch1 --name mycc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')"
peer lifecycle chaincode commit -o 127.0.0.1:7050 --channelID ch1 --name mycc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')" --peerAddresses 127.0.0.1:7051

#12 -- Invoke chaincode
CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n mycc -c '{"Args":["init","a","100","b","200"]}' --isInit

timeout 5 tail -f peer.log chaincode.log orderer.log || true

CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n mycc -c '{"Args":["invoke","a","b","10"]}'

timeout 5 tail -f peer.log chaincode.log orderer.log || true

CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n mycc -c '{"Args":["query","a"]}'

timeout 5 tail -f peer.log chaincode.log orderer.log || true

cd $ORIGDIR

kill %3

bash
