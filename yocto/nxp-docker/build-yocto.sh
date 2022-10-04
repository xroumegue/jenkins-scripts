#! /bin/bash

set -ux

REALPATH="$(readlink -e "$0")"
BASEDIR="$(dirname "${REALPATH}")"

while getopts "u:d:M:t:m:b:S:D:Y:P:H:" OPTION; do
    case ${OPTION} in
        u)
            REMOTE=${OPTARG}
            ;;
        d)
            DISTRO=${OPTARG}
            ;;
        M)
            MACHINE=${OPTARG}
            ;;
        t)
            TARGET=${OPTARG}
            ;;
        m)
            MANIFEST=${OPTARG}
            ;;
        b)
            BRANCH=${OPTARG}
            ;;
    S)
        SSTATE_DIR=${OPTARG}
        ;;
    D)
        DOWNLOAD_DIR=${OPTARG}
        ;;
    Y)
        YOCTO_DIR=${OPTARG}
        ;;
    P)
        PRSERVER_HOST=${OPTARG}
        ;;
    H)
        HSERVER_HOST=${OPTARG}
        ;;
    esac
done

shift $((OPTIND-1))

unset OPTIND


: "${DISTRO:=fsl-imx-internal-xwayland}"
: "${MACHINE:=imx8mpevk}"
: "${TARGET:=test-internal-qt6}"
: "${MANIFEST:=default}"
: "${BRANCH:=linux-kirkstone-internal}"
: "${REMOTE:=ssh://bitbucket.sw.nxp.com/imx/imx-manifest}"
: "${YOCTO_DIR:=$(pwd)/yocto}"
: "${SSTATE_DIR:=$YOCTO_DIR/sstate-cache}"
: "${DOWNLOAD_DIR:=$YOCTO_DIR/downloads}"
: "${REPO_REV:=stable}"
: "${BB_THREADS:=$(nproc)}"
: "${PARALLEL_MAKE:=$(nproc)}"
: "${PRSERVER_HOST:=$(hostname -s):8585}"
: "${HSERVER_HOST:=$(hostname -s):8686}"

[ -e ${YOCTO_DIR} ] || mkdir -p ${YOCTO_DIR}
cd ${YOCTO_DIR}

. /etc/lsb-release

if [[ ${DISTRIB_RELEASE} == '16.04' ]];
then
    REPO_REV=maint
fi

repo init \
    --repo-branch=${REPO_REV} \
    -u ${REMOTE} \
    -b ${BRANCH} \
    -m ${MANIFEST}.xml

repo sync

set +u
EULA=1 DISTRO="${DISTRO}" MACHINE="${MACHINE}" source fsl-setup-internal-build.sh -b build-${TARGET}-${MANIFEST}
#source ../sources/meta-fsl-mpu-internal/build/hook-in-internal-servers.sh
#source ../sources/imx-build-bamboo/build/hook-in-internal-servers.sh
set -u

BB_LOCAL_CONF="conf/local.conf"
BB_LAYERS_CONF="conf/bblayers.conf"

# Remove variables we want to overidde anyway.
sed -i -e '/DL_DIR/d' "${BB_LOCAL_CONF}"
sed -i -e '/SSTATE_DIR/d' "${BB_LOCAL_CONF}"
sed -i -e '/BB_HASHSERVE/d' "${BB_LOCAL_CONF}"
sed -i -e '/PRSERV_HOST/d' "${BB_LOCAL_CONF}"

if ! grep -Eq '^BB_NICE_LEVEL '  "${BB_LOCAL_CONF}" ; then
    echo "BB_NICE_LEVEL = \"10\"" >> "${BB_LOCAL_CONF}"
fi

if ! grep -Eq '^BB_HASHSERVE ' "${BB_LOCAL_CONF}" ; then
    echo "BB_HASHSERVE = \"${HSERVER_HOST}\"" >> "${BB_LOCAL_CONF}"
fi

if ! grep -Eq '^PRSERV_HOST ' "${BB_LOCAL_CONF}" ; then
    echo "PRSERV_HOST = \"${PRSERVER_HOST}\"" >> "${BB_LOCAL_CONF}"
fi

if ! grep -Eq '^BB_NUMBER_THREADS ' "${BB_LOCAL_CONF}" ; then
    echo "BB_NUMBER_THREADS ?= \"${BB_THREADS}\"" >> "${BB_LOCAL_CONF}"
fi

if ! grep -Eq '^PARALLEL_MAKE ' "${BB_LOCAL_CONF}" ; then
    echo "PARALLEL_MAKE ?= \"-j ${PARALLEL_MAKE}\"" >> "${BB_LOCAL_CONF}"
fi

#if ! grep -Eq '^MACHINE_FEATURES_remove' "${BB_LOCAL_CONF}" ; then
#    echo 'MACHINE_FEATURES_remove = "nxp8987"' >> "${BB_LOCAL_CONF}"
#fi

if ! grep -Eq '^SSTATE_DIR' "${BB_LOCAL_CONF}" ; then
    echo "SSTATE_DIR ?= \"${SSTATE_DIR}\"" >> "${BB_LOCAL_CONF}"
fi

if ! grep -Eq '^DL_DIR' "${BB_LOCAL_CONF}" ; then
    echo "DL_DIR ?= \"${DOWNLOAD_DIR}\"" >> "${BB_LOCAL_CONF}"
fi

if ! grep -Eq '^OE_TERMINAL' "${BB_LOCAL_CONF}" ; then
    echo 'OE_TERMINAL = "screen"' >> "${BB_LOCAL_CONF}"
fi

bitbake packagegroup-imx-ml && bitbake packagegroup-qt6-imx && bitbake ${TARGET}
