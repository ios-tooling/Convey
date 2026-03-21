# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Convey is a Swift Package Manager library for iOS, macOS, tvOS, visionOS, and watchOS that simplifies complex HTTP network operations. It provides a server-task architecture for managing network communications with built-in caching, error handling, and SwiftUI integration.

## Development Commands

### Building and Testing
- **Build**: `swift build`
- **Test**: `swift test`
- **Single test**: `swift test --filter <TestName>`
- **Debug mode fail-all flag**: Run with `-fail-all-requests` command line argument to make all network requests fail immediately (useful for testing error handling)

### Project Structure
- **Main library**: `Sources/Convey/` - Core framework code
- **Test harness app**: `ConveyTestHarness/` - SwiftUI test application (open in Xcode and run ConveyTestHarness target)
- **Tests**: `Tests/ConveyTests/` - Unit tests using Swift Testing framework (not XCTest). Some test files are `.disabled` (e.g., `MIMETests.swift.disabled`) — these are intentionally excluded from compilation.
- **Package definition**: `Package.swift` - SPM configuration
- **Dependencies**: JohnnyCache (https://github.com/ios-tooling/JohnnyCache.git) for caching, Chronicle (https://github.com/ios-tooling/Chronicle/) for logging

### Source Directory Organization
- `Caching/` - ETag store, file watching, image sizing
- `Configuration/` - Remote environments, server/task configuration, command line options
- `Errors/` - HTTPError with ClientError (4xx) and ServerError (5xx) enums
- `Extensions/` - Helpers for Bundle, Data, FileManager, URL, URLSession, MD5
- `Server/` - ConveyServer class and ConveyServerable protocol
- `TaskRecording/` - SwiftData-based task recording for debugging (RecordedTask model, TaskRecorder, TaskObserver)
- `Tasks/` - All task protocols and implementations (DownloadingTask, uploading variants, echoing)
- `UI/` - SwiftUI views (CachedURLImage, RecordedTasksScreen, TaskRow, etc.)
- `Utility/` - ConveyActor, ConveySession, Headers, HTTPMethod, threading primitives

## Architecture

### Core Components
- **ConveyServer**: Central server management class that handles remote connections, configuration, and session management. Subclass this for your app's server.
- **DownloadingTask**: Main protocol that all tasks implement, providing HTTP operation definitions and lifecycle hooks. `ServerTask` is a typealias for `DataDownloadingTask`.
- **ConveyServerable**: Protocol that defines server behavior for handling remote connections and configuration.

### Key Patterns
- **Actor-based concurrency**: Uses `@ConveyActor` global actor for thread-safe operations. All protocols and key types are marked with `@ConveyActor` to ensure thread-safe execution.
- **Protocol composition**: Tasks combine multiple protocols (e.g., `UploadingTask`, `DataUploadingTask`) to define behavior. Tasks are typically defined as structs conforming to these protocols.
- **Configuration via Remote**: Environment switching through `Remote` objects for different endpoints. Set the `remote` property on your server to switch between dev/staging/prod environments.
- **HTTP method specification**: Tasks define their HTTP method via the `method` property. Uses `HTTPMethod` enum (`.get`, `.post`, `.put`, `.patch`, `.delete`). Defaults to `.get` if not specified.
- **Server-task architecture**: `ConveyServerable` protocol defines server behavior, tasks implement `DownloadingTask`. Most apps will have a single `ConveyServer` subclass as a singleton.
- **Type safety**: Strong typing with associated types for upload/download payloads. `DownloadPayload` and `UploadPayload` are defined via associated types on protocols.
- **Default server pattern**: When creating a `ConveyServer` with `init(asDefault: true)`, tasks without an explicit `server` property will use this default server automatically.

### Protocol Hierarchy
- `DownloadingTask<DownloadPayload>` - Base protocol for all network tasks
- `DataDownloadingTask` - Convenience for tasks that download raw `Data`. `ServerTask` is a typealias for this.
- `UploadingTask<UploadPayload>` - Adds upload capabilities with associated type
- `DataUploadingTask` - Upload and download raw `Data`
- `JSONUploadingTask` - JSON-based uploads with automatic encoding
- `FormUploadingTask` - Form-encoded uploads
- `MIMEUploadingTask` - Multipart MIME uploads
- `EchoingTask` - Marker protocol enabling full console logging and recording
- `NonEchoingTask` - Marker protocol disabling all logging
- `IgnoredResultsTask` - For tasks where the response data is not needed

### Response Handling
- **ServerResponse<Payload>**: Generic response wrapper containing the decoded payload, raw data, HTTP response, request, timing info, and attempt number
- Responses include `statusCode`, `httpResponse`, `responseType` (info/success/redirect/clientError/serverError), `duration`, and `stringResult` properties
- Can re-decode response to different type via `decoding(using:)` method

### Caching System
- **DataCache**: Actor-based caching with local-first, remote-first, and skip-local strategies
- **ImageCache**: Specialized image caching with SwiftUI integration via `CachedURLImage`
- **ETagStore**: HTTP ETag support for cache validation
- Backed by JohnnyCache library for underlying cache implementation

### Task Recording System
- **RecordedTask**: SwiftData model for persisting network task execution details
- **TaskRecorder**: Handles recording of task execution for debugging and analysis
- **TaskObserver**: Observes task execution events
- SwiftUI screens for browsing recorded tasks: `RecordedTasksScreen`, `RecordedTaskDetailScreen`, `RecordedTasksButton`

### Platform Support
- Minimum versions: iOS 14+, macOS 14+, watchOS 7+
- Swift 6.0+ required for concurrency features
- Uses system-zlib for compression (separate target in Package.swift)

## Important Implementation Details

### Error Handling
- **HTTPError**: Handles HTTP-specific errors with `ClientError` (4xx) and `ServerError` (5xx) sub-enums
- Tasks can implement `didFail(with:)` for custom error handling
- Tasks can implement `retryInterval(afterError:count:)` to enable automatic retry with custom intervals

### Network Configuration
- **ConveySession**: Manages individual network sessions and URLSession instances. Can be cancelled by tag via `ConveySession.cancel(sessionWithTag:)`
- **TaskConfiguration**: Per-task configuration overrides for timeouts, network access policies, echo styles
- **ServerConfiguration**: Global server settings (encoder/decoder, timeout, headers, user agent, gzip, network access policies)
- **Remote**: Represents an environment (dev/staging/prod) with URL and common path prefixes

### Task Lifecycle Hooks
Tasks can implement these optional lifecycle methods (all have default empty implementations):
- `willSendRequest(request:)` - Modify request before sending
- `didReceiveResponse(response:data:)` - Validate response before decoding (can throw)
- `didFail(with:)` - Custom error handling
- `didFinish(with:)` - Handle successful completion
- `retryInterval(afterError:count:)` - Return `TimeInterval` to retry, or `nil` to stop

### Server Customization Hooks
Override in `ConveyServer` subclass:
- `headers(for:)` - Custom headers per task (combines with `defaultHeaders`)
- `didFinish(task:response:error:)` - Called after every task completion
- `server.disabled = true` - Fail all tasks immediately

### Echo/Logging System
- Tasks control logging via `echoStyle` property returning a `TaskEchoStyle` option set
- Styles: `.consoleMinimum`, `.consoleRequest`, `.consoleFull`, `.console5k`/`.console10k`/`.console30k`/`.console100k`, `.recorded`, `.onlyIfError`
- Default style is `.recorded`
- `EchoingTask` enables `[.consoleFull, .recorded]`; `NonEchoingTask` disables all
- `echoStyle(for data: Data?)` allows conditional logging based on response data
