#!/bin/bash -exu

# From https://github.com/hyperledger/fabric docs/source/peer-chaincode-devmode.md

trap "exit" INT TERM
trap "kill 0" EXIT

SRCDIR=$(realpath $(dirname $0))

ORIGDIR=$PWD

DESTDIR=$1

mkdir $1

cd $1


# # 1 -- Clone
git clone https://github.com/hyperledger/fabric --branch release-2.3 --depth=1
cd fabric

# # Additional change configuration
sed -i sampleconfig/core.yaml sampleconfig/orderer.yaml -e "s&/var/hyperledger/production&$PWD/../tmp&g"
sed -i sampleconfig/core.yaml -e "s&127.0.0.1:9443&127.0.0.1:9447&g"
sed -i sampleconfig/core.yaml -e "s&0.0.0.0:7051&127.0.0.1:7051&g"

# # 2 -- Build
make orderer peer configtxgen

# 2.5 create package

rm -rf $DESTDIR/package; mkdir $DESTDIR/package; cd $DESTDIR/package
echo '{"path":"fabric-chaincode-ocaml/tests/simple","type":"ocaml","label":"mycc"}' > metadata.json

tar -czf code.tar.gz -C $SRCDIR/pkg --exclude=_build --exclude=.git --exclude=_opam --exclude=pkg . ../../../../fabric-chaincode-ocaml/

tar -czf mycc.tar.gz code.tar.gz metadata.json

cd $DESTDIR/fabric

# 2.6 create external launcher

rm -rf $DESTDIR/bin/; mkdir $DESTDIR/bin/

cat - > $DESTDIR/bin/detect <<EOF
#!/bin/sh -eux

rm -f /tmp/detect.log
exec 1>/tmp/detect.log 2>&1

CHAINCODE_METADATA_DIR="\$2"

pwd
env
tree \$1
tree \$2
which jq
echo "\$CHAINCODE_METADATA_DIR/metadata.json"
cat "\$CHAINCODE_METADATA_DIR/metadata.json"

echo "\$(jq -r .type "\$CHAINCODE_METADATA_DIR/metadata.json" | tr '[:upper:]' '[:lower:]')"

# use jq to extract the chaincode type from metadata.json and exit with
# success if the chaincode type is ocaml
if [ "\$(jq -r .type "\$CHAINCODE_METADATA_DIR/metadata.json" | tr '[:upper:]' '[:lower:]')" = "ocaml" ]; then
    exit 0
fi

exit 1
EOF

cat - > $DESTDIR/bin/build <<EOF
#!/bin/sh -eux

rm -f /tmp/build.log
exec 1>/tmp/build.log 2>&1

date

CHAINCODE_SOURCE_DIR="\$1"
CHAINCODE_METADATA_DIR="\$2"
BUILD_OUTPUT_DIR="\$3"

dune build --root=\$CHAINCODE_SOURCE_DIR
dune install --root=\$CHAINCODE_SOURCE_DIR --prefix=\$BUILD_OUTPUT_DIR --verbose
echo done
EOF

cat - > $DESTDIR/bin/run <<EOF
#!/bin/sh -eux

exec 1>/tmp/run.log 2>&1

date

BUILD_OUTPUT_DIR="\$1"
RUN_METADATA_DIR="\$2"

# setup the environment expected by the go chaincode shim
export CORE_CHAINCODE_ID_NAME="\$(jq -r .chaincode_id "\$RUN_METADATA_DIR/chaincode.json")"
export CORE_PEER_TLS_ENABLED="true"
export CORE_TLS_CLIENT_CERT_FILE="\$RUN_METADATA_DIR/client.crt"
export CORE_TLS_CLIENT_KEY_FILE="\$RUN_METADATA_DIR/client.key"
export CORE_PEER_TLS_ROOTCERT_FILE="\$RUN_METADATA_DIR/root.crt"
export CORE_PEER_LOCALMSPID="\$(jq -r .mspid "\$RUN_METADATA_DIR/chaincode.json")"
PEER_ADDRESS="\$(jq -r .peer_address "\$RUN_METADATA_DIR/chaincode.json")"

\$BUILD_OUTPUT_DIR/bin/chaincode \$PEER_ADDRESS \$CORE_CHAINCODE_ID_NAME

EOF

chmod u+x $DESTDIR/bin/*

# 3 -- PATH
export CORE_CHAINCODE_EXTERNALBUILDERS="[{name: ocaml, path: \"$DESTDIR/\"}]"
export PATH=$(pwd)/build/bin:$PATH

# 4 -- Set config path
export FABRIC_CFG_PATH=$(pwd)/sampleconfig

# 5 -- Genesis block
rm -rf sampleconfig/genesisblock ch1.block ch1.tx $DESTDIR/tmp
configtxgen -profile SampleDevModeSolo -channelID syschannel -outputBlock genesisblock -configPath $FABRIC_CFG_PATH -outputBlock $(pwd)/sampleconfig/genesisblock

# 6 -- Start orderer
ORDERER_GENERAL_GENESISPROFILE=SampleDevModeSolo orderer >& orderer.log &

timeout 2 tail -f orderer.log || true

# 7 -- Start peer

FABRIC_LOGGING_SPEC=chaincode=debug CORE_PEER_CHAINCODELISTENADDRESS=127.0.0.1:7052 peer node start >& peer.log &

timeout 5 tail -f peer.log || true

# 8 -- Create channel ch1
configtxgen -channelID ch1 -outputCreateChannelTx ch1.tx -profile SampleSingleMSPChannel -configPath $FABRIC_CFG_PATH
peer channel create -o 127.0.0.1:7050 -c ch1 -f ch1.tx

peer channel join -b ch1.block


#9 Install custom chaincode
peer lifecycle chaincode install $DESTDIR/package/mycc.tar.gz |& tee chaincode-install.log

ID=$(sed -ne "s/^.*code package identifier: mycc:\([a-z0-9]*\).*$/\1/p" chaincode-install.log)

test -n "$ID"

# 11 -- Approve and commit the chaincode definition

peer lifecycle chaincode approveformyorg  -o 127.0.0.1:7050 --channelID ch1 --name mycc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')" --package-id mycc:$ID
peer lifecycle chaincode checkcommitreadiness -o 127.0.0.1:7050 --channelID ch1 --name mycc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')"
peer lifecycle chaincode commit -o 127.0.0.1:7050 --channelID ch1 --name mycc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')" --peerAddresses 127.0.0.1:7051

CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n mycc -c '{"Args":["init","a","100","b","200"]}' --isInit


cd $ORIGDIR

bash
