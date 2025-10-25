Finding the size of Apple M3 GPU cache by trying to evict the cache line from GPU using an eviction buffer.

Xcode is prerequesite to run the code.

To run in Xcode, open project and click run.

Xcode is prerequisite

To run via command line, install command line tools for Xcode:

```
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

To build using terminal:

```
xcodebuild -scheme GPUCacheEvictor -derivedDataPath build
```

To run in terminal:

```
./build/Build/Products/Debug/GPUCacheEvictor.app/Contents/MacOS/GPUCacheEvictor
```

There are 2 possible access patterns of the eviction buffer to choose from in the dropdown menu: Linear and Random.

To change the range of the buffer (in MB) to test with, manually adjust the line (47):
```
let testSizesInKB = Array(stride(from:1, through: 4*1024, by: 1))
```
in ```Renderer.swift```

