#!/bin/bash
# -----------------------------------------------------------------------------
#
# Package          : openmpi
# Version          : 5.0.10
# Source repo      : https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.10.tar.gz
# Tested on        : UBI:10.2
# Language         : C
# Travis-Check     : True
# Script License   : Apache License, Version 2 or later
# Maintainer       : Rushikesh Sathe <Rushikesh.Sathe1@ibm.com>
#
# Disclaimer       : This script has been tested in root mode on given
# ==========         platform using the mentioned version of the package.
#                    It may not work as expected with newer versions of the
#                    package and/or distribution. In such case, please
#                    contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------

PACKAGE_NAME=openmpi
PACKAGE_VERSION=${1:-5.0.10}
PACKAGE_VERSION_DIR=5.0
PACKAGE_URL=https://download.open-mpi.org/release/open-mpi/v${PACKAGE_VERSION_DIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz

CURRENT_DIR=${PWD}

dnf install -y git make wget \
    zlib-devel openssl openssl-devel \
    autoconf automake libtool \
    python3.14 python3.14-devel python3.14-pip

yum install -y gcc-toolset-15
export PATH=/opt/rh/gcc-toolset-15/root/usr/bin:$PATH

# Only if need GCC Toolset 15 runtime libraries:
export LD_LIBRARY_PATH=/opt/rh/gcc-toolset-15/root/usr/lib64:$LD_LIBRARY_PATH

export CC=gcc
export CXX=g++

python3.14 -m pip install --upgrade pip setuptools wheel

cd $CURRENT_DIR
wget $PACKAGE_URL
tar -xzf ${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz
cd ${PACKAGE_NAME}-${PACKAGE_VERSION}

mkdir -p prefix
export PREFIX=$(pwd)/prefix

./configure --prefix=$PREFIX \
            --disable-dependency-tracking \
            --enable-shared \
            --disable-static

make -j$(nproc)
make install

cd $CURRENT_DIR

mkdir -p $CURRENT_DIR/local/openmpi
cp -r ${PACKAGE_NAME}-${PACKAGE_VERSION}/prefix/* $CURRENT_DIR/local/openmpi/

cd $CURRENT_DIR

wget https://raw.githubusercontent.com/i-wheels-cpd/build-scripts/refs/heads/main/o/openmpi/pyproject.toml
sed -i "s/{PACKAGE_VERSION}/$PACKAGE_VERSION/g" pyproject.toml


if ! python3.14 -m pip wheel -w $CURRENT_DIR -vv --no-build-isolation --no-deps . ; then
    echo "------------------$PACKAGE_NAME:Install_fails-------------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  |  $PACKAGE_URL | $PACKAGE_VERSION | upstream | Fail |  Install_Fails"
    exit 1
fi

python3.14 -m pip install ${PACKAGE_NAME}-*.whl

OPENMPI_INSTALL_PATH=$(python3.14 -c "import openmpi; print(list(openmpi.__path__)[0])")
export PATH=${OPENMPI_INSTALL_PATH}/bin:${PATH}
export LD_LIBRARY_PATH=${OPENMPI_INSTALL_PATH}/lib:${LD_LIBRARY_PATH}
export OPAL_PREFIX=${OPENMPI_INSTALL_PATH}

# compile and run a basic MPI hello-world
cat > /tmp/helloworld_mpi.c <<'EOF'
#include <mpi.h>
#include <stdio.h>
int main(int argc, char *argv[]) {
    int size, rank;
    MPI_Init(&argc, &argv);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    printf("Hello from rank %d of %d\n", rank, size);
    MPI_Finalize();
    return 0;
}
EOF

mpicc /tmp/helloworld_mpi.c -o /tmp/helloworld_mpi

if [ $? -ne 0 ]; then
    echo "------------------$PACKAGE_NAME:Test_Fails-------------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  |  $PACKAGE_URL | $PACKAGE_VERSION | Fail | Test_Fails"
    exit 1
else
    echo "------------------$PACKAGE_NAME:install_&_test_both_success-------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  |  $PACKAGE_URL | $PACKAGE_VERSION | Pass |  Both_Install_and_Test_Success"
    exit 0
fi
