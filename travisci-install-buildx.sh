#!/bin/bash

# This script is used to install docker buildx in travis-ci

# Stop at any error, show all commands
set -exuo pipefail

BUILDX_MACHINE=$(uname -m)
if [ ${BUILDX_MACHINE} == "x86_64" ]; then
	BUILDX_MACHINE=amd64
elif [ ${BUILDX_MACHINE} == "aarch64" ]; then
	BUILDX_MACHINE=arm64
fi

if [ ${BUILDX_MACHINE} == "ppc64le" ]; then
	# We need to run a rootless docker daemon due to travis-ci LXD configuration
	# Update docker, c.f. https://developer.ibm.com/components/ibm-power/tutorials/install-docker-on-linux-on-power/
	sudo systemctl stop docker
	sudo apt-get update
	sudo apt-get remove -y docker docker.io containerd runc
	sudo apt-get install -y --no-install-recommends containerd uidmap slirp4netns fuse-overlayfs
	# issues with SSL certificate expiring, let's go insecure & check sha256
	curl --insecure -fsSLO https://oplab9.parqtec.unicamp.br/pub/ppc64el/docker/version-20.10.6/ubuntu-focal/docker-ce-cli_20.10.6~3-0~ubuntu-focal_ppc64el.deb
	curl --insecure -fsSLO https://oplab9.parqtec.unicamp.br/pub/ppc64el/docker/version-20.10.6/ubuntu-focal/docker-ce_20.10.6~3-0~ubuntu-focal_ppc64el.deb
	curl --insecure -fsSLO https://oplab9.parqtec.unicamp.br/pub/ppc64el/docker/version-20.10.6/ubuntu-focal/docker-ce-rootless-extras_20.10.6~3-0~ubuntu-focal_ppc64el.deb
	cat <<EOF > docker-ce-ppc64le.sha256
e4304b2e20d79e94f0c4e105bb4abbddb637a83c0bad164a56660c65f0d77631  docker-ce_20.10.6~3-0~ubuntu-focal_ppc64el.deb
cd31d12aee7bd91ccb726ab750d382631fcc21ae2de64ab9868dcd275bcfa112  docker-ce-cli_20.10.6~3-0~ubuntu-focal_ppc64el.deb
0117a2edea9b2fa75410dc3f62e64ee82282bfe5b07c508b01508661ce2c3861  docker-ce-rootless-extras_20.10.6~3-0~ubuntu-focal_ppc64el.deb
EOF
	sha256sum -c docker-ce-ppc64le.sha256
	rm -f docker-ce-ppc64le.sha256
	# prevent the docker service to start upon installation
	echo -e '#!/bin/sh\nexit 101' | sudo tee /usr/sbin/policy-rc.d
	sudo chmod +x /usr/sbin/policy-rc.d
	# install docker
	sudo dpkg -i docker-ce-cli_20.10.6~3-0~ubuntu-focal_ppc64el.deb docker-ce-rootless-extras_20.10.6~3-0~ubuntu-focal_ppc64el.deb docker-ce_20.10.6~3-0~ubuntu-focal_ppc64el.deb
	# "restore" policy-rc.d
	sudo rm -f /usr/sbin/policy-rc.d
	# prepare & start the rootless docker daemon
	dockerd-rootless-setuptool.sh install --force
	export XDG_RUNTIME_DIR=/home/travis/.docker/run
	dockerd-rootless.sh &> /dev/null &
	DOCKERD_ROOTLESS_PID=$!
	echo "${DOCKERD_ROOTLESS_PID}" > ${HOME}/dockerd-rootless.pid
	docker context use rootless
fi
mkdir -vp ~/.docker/cli-plugins/
curl -sSL "https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-${BUILDX_MACHINE}" > ~/.docker/cli-plugins/docker-buildx
chmod a+x ~/.docker/cli-plugins/docker-buildx
docker buildx version

docker buildx create --name builder-manylinux --driver docker-container --use
if [ ${BUILDX_MACHINE} == "ppc64le" ]; then
	# start the container without --userns=host
	# https://github.com/docker/buildx/issues/561
	docker run -d --name buildx_buildkit_builder-manylinux0 --privileged moby/buildkit:buildx-stable-1
fi
docker buildx inspect --bootstrap --builder builder-manylinux
