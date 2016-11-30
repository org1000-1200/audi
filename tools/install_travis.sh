#!/bin/bash
set -e -x

yum install -y gmp-devel

cd /audi
echo "environment variables passed to docker:"
echo ${BUILD_TYPE}
echo ${PATH_TO_PYTHON}
echo ${PYTHON_VERSION}
# Compile and install boost
wget --no-check-certificate https://sourceforge.net/projects/boost/files/boost/1.62.0/boost_1_62_0.tar.bz2 > /dev/null 2>&1
tar --bzip2 -xf /audi/boost_1_62_0.tar.bz2 > /dev/null 2>&1
cd boost_1_62_0
./bootstrap.sh
# removing the wrongly detected python 2.4 (deletes 5 lines after the comment)
sed -i.bak -e '/# Python configuration/,+5d' ./project-config.jam
# defining the correct location for python
echo "using python" >> project-config.jam
echo "     : ${PYTHON_VERSION}" >> project-config.jam
echo "     : ${PATH_TO_PYTHON}/bin/python"  >> project-config.jam
echo "     : ${PATH_TO_PYTHON}/include/python${PYTHON_VERSION}m"  >> project-config.jam
echo "     : ${PATH_TO_PYTHON}/lib"  >> project-config.jam
echo "     ;" >> project-config.jam  >> project-config.jam

# Add here the boost libraries that are needed
./b2 install cxxflags="-std=c++11" --with-python --with-serialization --with-iostreams --with-regex --with-chrono --with-timer --with-test --with-system > /dev/null 2>&1
cd ..

# Install cmake
wget --no-check-certificate https://cmake.org/files/v3.7/cmake-3.7.0.tar.gz > /dev/null 2>&1
tar xvf /audi/cmake-3.7.0.tar.gz > /dev/null 2>&1
cd cmake-3.7.0
./bootstrap > /dev/null 2>&1
make > /dev/null 2>&1
make install
cd ..

# Install mpfr
wget http://www.mpfr.org/mpfr-current/mpfr-3.1.5.tar.gz > /dev/null 2>&1
tar xvf mpfr-3.1.5.tar.gz
cd mpfr-3.1.5
./configure > /dev/null 2>&1
make > /dev/null 2>&1
make install
cd ..

# Install gmp
curl https://gmplib.org/download/gmp/gmp-6.1.1.tar.bz2 > gmp-6.1.1.tar.bz2
tar xvf gmp-6.1.1.tar.bz2  > /dev/null 2>&1
cd gmp-6.1.1
./configure > /dev/null 2>&1
make > /dev/null 2>&1
make install
cd ..


# Install piranha
wget https://github.com/bluescarni/piranha/archive/v0.8.tar.gz > /dev/null 2>&1
tar xvf v0.8
cd piranha-0.8
mkdir build
cd build
cmake ../
make install
cd ..
# Apply patch
wget https://github.com/darioizzo/piranha/blob/master/src/thread_management.hpp
rm /usr/local/include/piranha/thread_management.hpp
cp thread_management.hpp /usr/local/include/piranha/

# Install and compile pyaudi
mkdir build
cd build


# Compile wheels
for PYBIN in /opt/python/*/bin; do
    ${PYBIN}/pip wheel /audi/ -w wheelhouse/
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/*.whl; do
    auditwheel repair $whl -w /io/wheelhouse/
done

# Install packages and test
for PYBIN in /opt/python/*/bin/; do
    ${PYBIN}/pip install python-manylinux-demo --no-index -f /io/wheelhouse
    (cd $HOME; ${PYBIN}/nosetests pymanylinuxdemo)
done

# Python configuration
using python : 3.5 : /opt/python/cp35-cp35m/bin/python3 : /opt/python/cp35-cp35m/include/python3.5m : /opt/python/cp35-cp35m/lib;
