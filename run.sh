DOCKER_IMAGE=parsely/manylinux
docker pull $DOCKER_IMAGE 
docker run --rm -v `pwd`:/io -v ${WHEELHOUSE:-`pwd`/wheelhouse}:/io/wheelhouse $DOCKER_IMAGE /io/build-wheels.sh
