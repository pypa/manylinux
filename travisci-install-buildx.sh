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

if [ "${MANYLINUX_BUILD_FRONTEND:-}" == "buildkit" ]; then
	sudo apt-get update
	sudo apt-get remove -y fuse ntfs-3g
	sudo apt-get install -y --no-install-recommends runc containerd uidmap slirp4netns fuse-overlayfs
	curl -fsSL "https://github.com/moby/buildkit/releases/download/v0.9.3/buildkit-v0.9.3.linux-${BUILDX_MACHINE}.tar.gz" | sudo tar -C /usr/local -xz
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
	# We need to update docker to get buildx support, c.f. https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
	sudo systemctl stop docker
	sudo apt-get update
	sudo apt-get purge -y docker docker.io containerd runc
	sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	# prevent the docker service to start upon installation
	echo -e '#!/bin/sh\nexit 101' | sudo tee /usr/sbin/policy-rc.d
	sudo chmod +x /usr/sbin/policy-rc.d
	# install docker
	sudo apt-get install docker-ce docker-ce-cli docker-ce-rootless-extras
	# "restore" policy-rc.d
	sudo rm -f /usr/sbin/policy-rc.d
	sudo sed -i 's;fd://;unix://;g' /lib/systemd/system/docker.service
	sudo systemctl daemon-reload
	sudo systemctl start docker
fi
if [ "${MANYLINUX_BUILD_FRONTEND:-}" == "docker" ]; then
	exit 0
fi

# update buildx
mkdir -vp ~/.docker/cli-plugins/
curl -sSL "https://github.com/docker/buildx/releases/download/v0.8.2/buildx-v0.8.2.linux-${BUILDX_MACHINE}" > ~/.docker/cli-plugins/docker-buildx
chmod a+x ~/.docker/cli-plugins/docker-buildx
docker buildx version
docker buildx create --name builder-manylinux --driver docker-container --use
# Force plain output done with 2>&1 | tee /dev/null
docker buildx inspect --bootstrap --builder builder-manylinux 2>&1 | tee /dev/null
