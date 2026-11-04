<div align="center">
  <br/>
  <img src="assets/logo.png" alt="Silkite Logo" width="120"/>
  <br/>
  <h1>Silkite</h1>
  <br/>
</div>

A beautiful, cute telegram client built from scratch on top of TDlib

## Features

- Modern Qt6 Quick/QML user interface
- Native Linux desktop integration
- C++ backend with QML frontend

## Requirements

- CMake 3.24+
- Qt 6.5+ (Quick, Qml components)
- A C++20 compiler

## Build

```bash
# Configure and build
cd ~/Projects/silkite
# remove any preexisting build 
rm -rf build
#configure explicitly using gcc
CC=gcc CXX=g++ \
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug
#build
cmake --build build --parallel 4
# Run
./build/silkite
```

### For developers and testers

## Telegram authentication

Create an application at [my.telegram.org](https://my.telegram.org) and provide
the credentials only at runtime. Silkite does not store or hardcode them:

```bash
export SILKITE_API_ID=123456
export SILKITE_API_HASH='your-api-hash'
./build/silkite
```

## License

MIT
