# Compile on Ubuntu (WSL)
sudo apt install libsndfile1 libsndfile1-de
sudo apt install autoconf
autoreconf -f -i
./configure
make
sudo make install
