cmake -B build_windows -S . --preset x64-release -DBUILD_SAMPLES=OFF
cd build_windows
cmake --build . --verbose 