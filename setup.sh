# for compiling SFML:
# download SFML sources, unzip to e.g. ~/Downloads/SFML-2.5.1-Compiled/
# sudo apt-get install libopenal-dev
# cmake .
# make -j14

# you need to "source" this file
SFML=~/Downloads/SFML-2.5.1-Compiled
export LD_LIBRARY_PATH=$SFML/lib:`pwd`/lib/imgui-sfml
export LIBRARY_PATH=$SFML/lib
export SFML_INCLUDE_DIR=$SFML/include
export CXXFLAGS="-I$SFML/include"

# and initially you need to run once:
# shards install
