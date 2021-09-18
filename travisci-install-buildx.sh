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

if [ "${MANYLINUX_BUILD_FRONTEND:-}" == "docker" ]; then
	exit 0
fi

if [ "${MANYLINUX_BUILD_FRONTEND:-}" == "buildkit" ]; then
	sudo apt-get update
	sudo apt-get remove -y fuse ntfs-3g
	sudo apt-get install -y --no-install-recommends runc containerd uidmap slirp4netns fuse-overlayfs
	curl -fsSL "https://github.com/moby/buildkit/releases/download/v0.9.0/buildkit-v0.9.0.linux-${BUILDX_MACHINE}.tar.gz" | sudo tar -C /usr/local -xz
	cat <<EOF > /tmp/start-buildkitd.sh
buildkitd &> /dev/null &
BUILDKITD_PID=\$!
echo "\${BUILDKITD_PID}" > /tmp/buildkitd.pid
EOF
	sudo bash /tmp/start-buildkitd.sh
	DOCKER_WAIT_COUNT=0
	while ! sudo buildctl du &>/dev/null; do
		DOCKER_WAIT_COUNT=$(( ${DOCKER_WAIT_COUNT} + 1 ))
		if [ ${DOCKER_WAIT_COUNT} -ge 12 ]; then
			sudo buildctl du || true
			echo "buildkitd is still not running."
			sudo kill -15 $(cat /tmp/buildkitd.pid)
			exit 1
		fi
		sleep 5
	done
	sudo chmod 777 /run/buildkit
	sudo chmod 666 /run/buildkit/buildkitd.sock
	if ! buildctl du &>/dev/null; then
		buildctl du || true
		echo "can't connect to buildkitd."
		sudo kill -15 $(cat /tmp/buildkitd.pid)
		exit 1
	fi
	exit 0
fi

# default to docker-buildx frontend
if [ ${BUILDX_MACHINE} == "ppc64le" ]; then
	# We need to run a rootless docker daemon due to travis-ci LXD configuration
	# Update docker, c.f. https://developer.ibm.com/components/ibm-power/tutorials/install-docker-on-linux-on-power/
	sudo systemctl stop docker
	sudo apt-get update
	sudo apt-get remove -y docker docker.io containerd runc
	sudo apt-get install -y --no-install-recommends containerd uidmap slirp4netns fuse-overlayfs
	# issues with SSL certificate expiring, let's go insecure & check sha256
	curl --insecure -fsSLO https://oplab9.parqtec.unicamp.br/pub/ppc64el/docker/version-20.10.7/ubuntu-focal/docker-ce-cli_20.10.7~3-0~ubuntu-focal_ppc64el.deb
	curl --insecure -fsSLO https://oplab9.parqtec.unicamp.br/pub/ppc64el/docker/version-20.10.7/ubuntu-focal/docker-ce_20.10.7~3-0~ubuntu-focal_ppc64el.deb
	curl --insecure -fsSLO https://oplab9.parqtec.unicamp.br/pub/ppc64el/docker/version-20.10.7/ubuntu-focal/docker-ce-rootless-extras_20.10.7~3-0~ubuntu-focal_ppc64el.deb
	cat <<EOF > docker-ce-ppc64le.sha256
c42f4a9c7a5a99ef3c68de63165af9779350dff4cf3d000a399cac4915a2f4d7  docker-ce-cli_20.10.7~3-0~ubuntu-focal_ppc64el.deb
46b3c3f5886ccbc94aced0e773a7fba38847b1a9f3dcb36bb85e1d05776f66af  docker-ce-rootless-extras_20.10.7~3-0~ubuntu-focal_ppc64el.deb
c65ffa273ade99ee62690e9f1289cec479849a164a34e5a9e5ce459fad48b485  docker-ce_20.10.7~3-0~ubuntu-focal_ppc64el.deb
EOF
	sha256sum -c docker-ce-ppc64le.sha256
	rm -f docker-ce-ppc64le.sha256
	# prevent the docker service to start upon installation
	echo -e '#!/bin/sh\nexit 101' | sudo tee /usr/sbin/policy-rc.d
	sudo chmod +x /usr/sbin/policy-rc.d
	# install docker
	sudo dpkg -i docker-ce-cli_20.10.7~3-0~ubuntu-focal_ppc64el.deb docker-ce-rootless-extras_20.10.7~3-0~ubuntu-focal_ppc64el.deb docker-ce_20.10.7~3-0~ubuntu-focal_ppc64el.deb
	# "restore" policy-rc.d
	sudo rm -f /usr/sbin/policy-rc.d
	# prepare & start the rootless docker daemon
	dockerd-rootless-setuptool.sh install --force
	export XDG_RUNTIME_DIR=/home/travis/.docker/run
	dockerd-rootless.sh &> /dev/null &
	DOCKERD_ROOTLESS_PID=$!
	echo "${DOCKERD_ROOTLESS_PID}" > ${HOME}/dockerd-rootless.pid
	docker context use rootless
	DOCKER_WAIT_COUNT=0
	while ! docker ps -q &>/dev/null; do
		DOCKER_WAIT_COUNT=$(( ${DOCKER_WAIT_COUNT} + 1 ))
		if [ ${DOCKER_WAIT_COUNT} -ge 12 ]; then
			echo "Docker is still not running."
			kill -15 $(cat ${HOME}/dockerd-rootless.pid)
			exit 1
		fi
		sleep 5
	done
fi
mkdir -vp ~/.docker/cli-plugins/
curl -sSL "https://github.com/docker/buildx/releases/download/v0.6.3/buildx-v0.6.3.linux-${BUILDX_MACHINE}" > ~/.docker/cli-plugins/docker-buildx
chmod a+x ~/.docker/cli-plugins/docker-buildx
docker buildx version

docker buildx create --name builder-manylinux --driver docker-container --use
if [ ${BUILDX_MACHINE} == "ppc64le" ]; then
	# start the container without --userns=host
	# https://github.com/docker/buildx/issues/561
	docker run -d --name buildx_buildkit_builder-manylinux0 --privileged moby/buildkit:buildx-stable-1
fi
# Force plain output done with 2>&1 | tee /dev/null
docker buildx inspect --bootstrap --builder builder-manylinux 2>&1 | tee /dev/null
