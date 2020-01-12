bundle
sudo apt install libarchive-dev
cd pixz
./autogen.sh
./configure --without-manpage
make
cp src/pixz ../pixz-runtime

