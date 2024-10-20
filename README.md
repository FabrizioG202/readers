# Readers

`readers` is a dart library designed for efficient data buffering and parsing. It provides abstractions for handling data streams, including support for extending buffers and reading data incrementally. 

The package was created as a tool for parsing data, independently of its origin, whether it is a file, a network stream, or any other source. The seemingly unorthodox approach of using generators to handle data parsing was chosen to provide a framework that can be used indifferently with synchronous and asynchronous data sources.

> [!IMPORTANT]
> The package is still in an experimental stage, and the API could change. I would like to think this is the final structure of the API, but I cannot guarantee it. I am open to suggestions and feedback, so feel free to open an issue.

In general, I tried to design the API in such a way that would keep it out of the way of the user, while still providing a flexible and powerful tool for handling data.

## Features

- **Buffer Management**: Grow and manage data buffers efficiently.
- **Incremental Parsing**: Extend buffers until specific conditions are met.
- **Flexible Data Handling**: Supports both synchronous and asynchronous data sources, with a single API.

## Basic Framework Overview:

The following are the main abstractions provided by the package:

- **Buffer**: A buffer is a data structure that holds a sequence of bytes. It essentially provides a way to extend, read, and manage data efficiently. See `BytesBuffer` for a minimal concrete implementation.
- **PartialParseResult**: Represents a partial result of a parsing operation. It can be used to signal that more data is needed to complete the operation or that the operation is complete, returning a result.
- **Cursor**: A cursor is essentially a wrapper around a position, that can be passed around and be updated by different functions. It is used to keep track of the current position in a buffer.


The package also contains some concrete implementations for the abstractions above, such as `BytesBuffer` and `SyncFileSource`. A `handleSync` function is also provided, showing a simple example of how the API can be used. See the examples below or the `test` folder for more use cases. However, the main idea is that the user can create their own implementations of the abstractions provided by the package, to fit their specific needs. Hence, I am not sure if those utilities fit the scope of the package.

## Examples:
```dart

Iterable<PartialParseResult<String>> consume(Buffer b) sync* {
  // Require at least 100 bytes to continue
  yield ReadRequest.require(100);

  // here, you should safely assume that the buffer has at least 100 bytes

  // use the bytes...
  final bytes = b.getView();
}

Iterable<PartialParseResult<String>> consumeString(Buffer b) sync* {
  
  // Hold the parsing until the buffer contains a null character (0x00)
  // ! The `contains` callback is called on every buffer extension.
  // extendUntil will continue to hold back the parsing until the condition is met,
  // hence the `yield*`.
  yield* b.extendUntil((view) => view.contains(0x00));

  // Get a view of the buffer, without copying the data to avoid 
  // unnecessary memory allocations.
  final bytes = b.getView();
  yield CompleteParseResult(String.fromCharCodes(bytes));
}

```

## License: MIT
See the [LICENSE](LICENSE) file for license rights and limitations (MIT).