#!/bin/bash -e
set -o pipefail

REPO=$1

###################
# Install govender
###################
echo "Install govendor"
go get -u github.com/kardianos/govendor

echo "======== PULL DOCKER IMAGES ========"
##########################################################
# Pull and Tag the fabric and fabric-ca images from Nexus
##########################################################
WD=$GOPATH/src/github.com/hyperledger/fabric-test
cd $WD

echo "Fetching images from Nexus"
NEXUS_URL=nexus3.hyperledger.org:10001
ORG_NAME="hyperledger/fabric"
ARCH=$(go env GOARCH)
# The value for BASE_VERSION is defined in fabric-test Makefile
LATEST_TAG=${LATEST_TAG:=$ARCH-$BASE_VERSION-stable}
echo "---------> REPO:" $REPO
echo "---------> LATEST_TAG:" $LATEST_TAG


dockerTag() {
  IMAGELIST=$@
  echo "Images: $IMAGELIST"

  for IMAGE in $IMAGELIST; do
    echo "Image: $IMAGE"
    echo
    docker pull $NEXUS_URL/$ORG_NAME-$IMAGE:$LATEST_TAG
          if [ $? != 0 ]; then
             echo  "FAILED: Docker Pull Failed on $IMAGE"
             exit 1
          fi
    docker tag $NEXUS_URL/$ORG_NAME-$IMAGE:$LATEST_TAG $ORG_NAME-$IMAGE
    docker tag $NEXUS_URL/$ORG_NAME-$IMAGE:$LATEST_TAG $ORG_NAME-$IMAGE:$LATEST_TAG
    if [ $IMAGE == javaenv ]; then
        docker tag $NEXUS_URL/$ORG_NAME-$IMAGE:$LATEST_TAG $ORG_NAME-$IMAGE:$ARCH-$BASE_VERSION
    fi
    echo "$ORG_NAME-$IMAGE:$LATEST_TAG"
    echo "Deleting Nexus docker images: $IMAGE"
    docker rmi -f $NEXUS_URL/$ORG_NAME-$IMAGE:$LATEST_TAG
  done
}

dockerThirdParty() {
  for IMAGE in kafka zookeeper couchdb; do
    echo "$ORG_NAME-$IMAGE"
    # 3rd party images are on dockerhub
    # The value for BASEIMAGE_RELEASE is defined in fabric-test Makefile
    docker pull $ORG_NAME-$IMAGE:$ARCH-$BASEIMAGE_RELEASE
    if [ $? != 0 ]; then
       echo  "FAILED: Docker Pull Failed on $IMAGE"
       exit 1
    fi
    docker tag $ORG_NAME-$IMAGE:$ARCH-$BASEIMAGE_RELEASE $ORG_NAME-$IMAGE:latest
  done
}


case $REPO in
fabric)
  echo "Pull all images except fabric"
  dockerTag javaenv tools ca
  ;;
fabric-ca)
  echo "Pull all images except fabric-ca"
  dockerTag peer orderer ccenv tools javaenv
  ;;
fabric-sdk-node)
  echo "Pull all images except fabric-sdk-node"
  dockerTag peer orderer ccenv tools ca javaenv
  ;;
fabric-sdk-java)
  echo "Pull all images except fabric-sdk-java"
  dockerTag peer orderer ccenv tools ca javaenv
  ;;
fabric-javaenv)
  echo "Pull all images except fabric-javaenv"
  dockerTag peer orderer ccenv tools ca
  ;;
third-party)
  echo "Pull all third-party docker images"
  dockerThirdParty
  ;;
*)
  echo "Pull all images"
  dockerTag peer orderer ccenv tools ca javaenv
  ;;
esac

echo
docker images | grep "hyperledger*"
echo
