#! /bin/bash

set -eu

usage () {
    echo "Fatal:" "$@"
    cat <<EOF
    echo $0 [-n IMAGE_NAME]
EOF
    exit 1
}

REALPATH="$(readlink -e "$0")"
BASEDIR="$(dirname "${REALPATH}")"
IMAGE_NAME="nxp-yocto"

while getopts "n:b:" OPTION; do
    case ${OPTION} in
        n)
            IMAGE_NAME=${OPTARG}
            ;;
        b)
            BASEDIR=${OPTARG}
            ;;
        *)
            ;;
    esac
done

shift $((OPTIND-1))

docker image inspect "${IMAGE_NAME}" 1>&2>/dev/null || usage "${IMAGE_NAME} does not exist"

#
# Theorically, should get the user id within the container.
# But we use --user "$(id -u) while instantiating the container
# so use this assumption as this simplify the bootstrap (and avoid recursivity)
#
#BLD_UID=$(./docker-run-user.sh id -u)
#BLD_GID=$(./docker-run-user.sh id -g)

BLD_UID=1000
BLD_GID=1000

VOLUMES=(\
    "${BASEDIR}"/volume/yocto \
    "${BASEDIR}"/volume/tmp \
    "${BASEDIR}"/volume/downloads \
    "${BASEDIR}"/volume/sstate-cache
)

for volume in "${VOLUMES[@]}";
do
    if [ ! -d "${volume}" ];
    then
        echo Creating volume "$volume"
        mkdir -p "${volume}"
        if [[ "${volume}" =~ '/tmp' ]];
        then
            chmod 777 "${volume}"
        fi
        # change volume IDs to build-user IDs mapped outside the container
        podman unshare chown "${BLD_UID}":"${BLD_GID}" "${volume}"
    fi
done

eval "$(ssh-agent)"
docker run  \
     --volume "${BASEDIR}"/volume/yocto:/home/build-user/yocto:rw,z \
     --volume "${BASEDIR}"/volume/yocto/downloads:/home/build-user/yocto/downloads:rw,z \
     --volume "${BASEDIR}"/volume/yocto/sstate-cache:/home/build-user/yocto/sstate-cache:rw,z \
     --volume "${BASEDIR}"/volume/tmp:/tmp:rw,z \
     --user "${BLD_UID}" \
     --volume "${SSH_AUTH_SOCK}":/ssh-agent:ro,z \
     --env SSH_AUTH_SOCK=/ssh-agent \
     --rm \
     -ti "${IMAGE_NAME}" \
     "$@"
