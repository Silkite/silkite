<div align="center">
  <br/>
  <img src="assets/logo.png" alt="Silkite Logo" width="120"/>
  <br/>
  <h1>Silkite</h1>
  <br/>
</div>

A lightweight Linux desktop application built with **C++20**, **Qt6**, and **QML**.

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
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug
cmake --build build

# Run
./build/silkite
```

## License

MIT
