# Readers

`readers` is a dart library designed for efficient data buffering and parsing. It provides abstractions for handling data streams, including support for extending buffers and reading data incrementally.

The package was created as a tool for parsing data, independently of its origin, whether it is a file, a network stream, or any other source. The seemingly unorthodox approach of using generators to handle data parsing was chosen to provide a framework that can be used indifferently with synchronous and asynchronous data sources.

> [!IMPORTANT]
> The package is still in an experimental stage, and the API could change. I would like to think this is the final structure of the API, but I cannot guarantee it. I am open to suggestions and feedback, so feel free to open an issue.

> [!IMPORTANT]
> The Latest version introduced a shift in paradigm to enable compressed data parsing. This broke tests and basically all uses of the package.

In general, I tried to design the API in such a way that would keep it out of the way of the user, while still providing a flexible and powerful tool for handling data.

## Features

- **Buffer Management**: Grow and manage data buffers efficiently.
- **Incremental Parsing**: Extend buffers until specific conditions are met.
- **Flexible Data Handling**: Supports both synchronous and asynchronous data sources, with a single API.
- **Compression-agnostic parsing** (Experimental): Handle compressed data streams without the need for additional libraries and with an API that closely resembles the one for uncompressed data.

## Installation

This package is not available on pub.dev. Add it as a git dependency in your `pubspec.yaml`. See the [Dart documentation](https://dart.dev/tools/pub/dependencies#git-packages) for more details.

## Limitations

The peculiar workings of the package mean as it very easy to accidentally create endless loops. I am working on ways to make this harder to do, but for now, ensure your conditions for growing buffers and ending parsings are well-defined and will eventually be met.

## See It in Action

Check out the [biodart project](https://github.com/FabrizioG202/biodart) and especially the [`hic` module](https://github.com/FabrizioG202/biodart/tree/main/hic), where the package is heavily used to efficiently parse data incrementally.

## Basic Framework Overview:

The following are the main abstractions provided by the package:

- **Buffer**: A buffer is a data structure that holds a sequence of bytes. It essentially provides a way to extend, read, and manage data efficiently. See `BytesBuffer` for a minimal concrete implementation.
- **PartialParseResult**: Represents a partial result of a parsing operation. It can be used to signal that more data is needed to complete the operation or that the operation is complete, returning a result.
- **Cursor**: A cursor is essentially a wrapper around a position, that can be passed around and be updated by different functions. It is used to keep track of the current position in a buffer.

The package also contains some concrete implementations for the abstractions above, such as `BytesBuffer` and `SyncFileSource`. A `handleSync` function is also provided, showing a simple example of how the API can be used. See the examples below or the `test` folder for more use cases. However, the main idea is that the user can create their own implementations of the abstractions provided by the package, to fit their specific needs. Hence, I am not sure if those utilities fit the scope of the package.

## Examples:

Updated examples can be temporarily found in the `examples/` folder.

## License: MIT

See the [LICENSE](LICENSE) file for license rights and limitations (MIT).
