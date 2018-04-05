#!/bin/bash
set -e
NEXUS_BASEURL=http://ossnexus.pacificbiosciences.com/repository
#NEXUS_URL=$NEXUS_BASEURL/unsupported/gcc-4.9.2
if [ ! -e .distfiles/gtest/release-1.7.0.tar.gz ]; then
  mkdir -p .distfiles/gtest
  curl -sL $NEXUS_BASEURL/unsupported/distfiles/googletest/release-1.7.0.tar.gz \
    -o .distfiles/gtest/release-1.7.0.tar.gz
fi
tar zxf .distfiles/gtest/release-1.7.0.tar.gz -C repos/
ln -sfn googletest-release-1.7.0 repos/gtest

rm -rf deployment
mkdir -p deployment
/bin/ls -t tarballs/pbbam-*.tgz        | head -1 | xargs -r -n 1 cat | tar zxv --strip-components 3 -C deployment
/bin/ls -t tarballs/blasr_libcpp-*.tgz | head -1 | xargs -r -n 1 cat | tar zxv --strip-components 3 -C deployment
/bin/ls -t tarballs/blasr-*.tgz        | head -1 | xargs -r -n 1 cat | tar zxv --strip-components 2 -C deployment
DEPLOYMENT=$PWD/deployment

export PATH=$PWD/deployment/bin:$PATH
export LD_LIBRARY_PATH=$PWD/deployment/lib:$LD_LIBRARY_PATH

type module >& /dev/null || . /mnt/software/Modules/current/init/bash
module load git
module load gcc
module load ccache
if [[ $USER == bamboo ]]; then
  export CCACHE_DIR=/mnt/secondary/Share/tmp/bamboo.mobs.ccachedir
fi
module load boost
if [[ $BOOST_ROOT =~ /include ]]; then
  set -x
  BOOST_ROOT=$(dirname $BOOST_ROOT)
  set +x
fi
module load htslib
module load hdf5-tools
module load zlib

DAZZDB=$PWD/repos/dazzdb
DALIGNER=$PWD/repos/daligner
cd repos/pbdagcon
export CCACHE_BASEDIR=$PWD
rm -rf build
set -x
mkdir -p build
    BOOST_INCLUDE=$BOOST_ROOT/include \
LIBPBDATA_INCLUDE=$DEPLOYMENT/include/pbdata \
    LIBPBDATA_LIB=$DEPLOYMENT/lib \
 LIBBLASR_INCLUDE=$DEPLOYMENT/include/alignment \
     LIBBLASR_LIB=$DEPLOYMENT/lib \
LIBPBIHDF_INCLUDE=$DEPLOYMENT/include/hdf \
    LIBPBIHDF_LIB=$DEPLOYMENT/lib \
    PBBAM_INCLUDE=$DEPLOYMENT/include \
        PBBAM_LIB=$DEPLOYMENT/lib \
    HTSLIB_CFLAGS=$(pkg-config --cflags htslib) \
      HTSLIB_LIBS=$(pkg-config --libs htslib) \
     HDF5_INCLUDE=$(pkg-config --cflags-only-I hdf5|awk '{print $1}'|sed -e 's/^-I//') \
         HDF5_LIB=$(pkg-config --libs-only-L hdf5|awk '{print $1}'|sed -e 's/^-L//') \
     DALIGNER_SRC=$DALIGNER \
      DAZZ_DB_SRC=$DAZZDB \
        GTEST_SRC=$PWD/../gtest/src \
    GTEST_INCLUDE=$PWD/../gtest/include \
    ZLIB_LIBFLAGS="$(pkg-config --libs zlib)" \
./configure.py --build-dir=$PWD/build
sed -i -e 's/-lpbihdf/-llibcpp/;s/-lblasr//;s/-lpbdata//' build/defines.mk
make -C build
cp -a build/src/cpp/pbdagcon $DEPLOYMENT/bin/
cp -a build/src/cpp/dazcon   $DEPLOYMENT/bin/
cd ../..

myVERSION=`pbdagcon --version|awk '/version/{print $3}'`
#rm -rf tarballs && mkdir -p tarballs
cd deployment
tar zcf ../tarballs/pbdagcon-${myVERSION}.tgz bin/pbdagcon bin/dazcon
