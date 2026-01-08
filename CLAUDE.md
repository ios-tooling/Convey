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
- **Tests**: `Tests/ConveyTests/` - Unit tests using Swift Testing framework (not XCTest)
- **Package definition**: `Package.swift` - SPM configuration
- **Dependencies**: JohnnyCache (https://github.com/ios-tooling/JohnnyCache.git) for caching implementation

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

### Response Handling
- **ServerResponse<Payload>**: Generic response wrapper containing the decoded payload, raw data, HTTP response, request, timing info, and attempt number
- Responses include `statusCode`, `httpResponse`, `responseType` (info/success/redirect/clientError/serverError), `duration`, and `stringResult` properties
- Can re-decode response to different type via `decoding(using:)` method

### Caching System
- **DataCache**: Actor-based caching with local-first, remote-first, and skip-local strategies
- **ImageCache**: Specialized image caching with SwiftUI integration via `CachedURLImage`
- **ETagStore**: HTTP ETag support for cache validation
- Backed by JohnnyCache library for underlying cache implementation

### SwiftUI Integration
- **CachedURLImage**: Drop-in replacement for AsyncImage with caching
- **RecordedTasksScreen**: UI for viewing recorded network tasks
- **RecordedTaskDetailScreen**: Detailed view for individual recorded tasks
- **TaskRow**: Row component for displaying task information
- **RecordedTasksButton**: Button component to trigger display of recorded tasks

### Platform Support
- Minimum versions: iOS 14+, macOS 14+, watchOS 7+
- Swift 6.0+ required for concurrency features
- Uses system-zlib for compression

### Task Recording System
- **RecordedTask**: SwiftData model for persisting network task execution details
- **TaskRecorder**: Handles recording of task execution for debugging and analysis
- Tasks can be recorded to disk for later review and debugging
- RecordedTasksScreen provides UI for browsing recorded network activities

## Important Implementation Details

### Error Handling
- **HTTPError**: Handles HTTP-specific errors from server responses with detailed status code enums
  - **HTTPError.ClientError**: 4xx errors (badRequest, unauthorized, forbidden, notFound, etc.)
  - **HTTPError.ServerError**: 5xx errors (internalServer, badGateway, serviceUnavailable, etc.)
- Tasks can implement `didFail(with:)` for custom error handling
- Tasks can implement `retryInterval(afterError:count:)` to enable automatic retry with custom intervals

### Network Configuration
- **ConveySession**: Manages individual network sessions and URLSession instances. Can be cancelled by tag via `ConveySession.cancel(sessionWithTag:)`
- **TaskConfiguration**: Per-task configuration overrides for timeouts, network access policies, echo styles
- **ServerConfiguration**: Global server settings including:
  - `defaultEncoder`/`defaultDecoder` for JSON serialization
  - `reportBadHTTPStatusAsError` to control error throwing for non-200 status codes
  - `enableGZipDownloads` for compression
  - `defaultTimeout`, `allowsExpensiveNetworkAccess`, `allowsConstrainedNetworkAccess`, `waitsForConnectivity`
  - `userAgent` and `defaultHeaders` for request customization
- **Remote**: Represents an environment (dev/staging/prod) with URL and common path prefixes

### Task Lifecycle Hooks
Tasks can implement these optional lifecycle methods (all have default empty implementations):
- `willSendRequest(request:)` - Called before sending request, can be used to modify the request
- `didReceiveResponse(response:data:)` - Called when response received, before decoding. Can throw to fail the task
- `didFail(with:)` - Called on task failure, for custom error handling or logging
- `didFinish(with:)` - Called on successful completion with the decoded `ServerResponse<DownloadPayload>`
- `retryInterval(afterError:count:)` - Return a `TimeInterval` to automatically retry failed requests. Return `nil` to not retry. Receives error and attempt count.

### Server Customization Hooks
Subclass `ConveyServer` and override these methods to customize behavior:
- `headers(for:)` - Return custom headers for a task (combines with `defaultHeaders`)
- `didFinish(task:response:error:)` - Called after every task completes (success or failure)
- Can be disabled via `server.disabled = true` to fail all tasks immediately

### Protocol Hierarchy
- `DownloadingTask<DownloadPayload>` - Base protocol for all network tasks. All tasks must conform to this.
- `DataDownloadingTask` - Convenience for tasks that download raw `Data` (most common). `ServerTask` is a typealias for this.
- `UploadingTask<UploadPayload>` - Adds upload capabilities with associated type. Extends `DownloadingTask`.
- `DataUploadingTask` - For tasks that upload and download raw `Data`
- `JSONUploadingTask` - For JSON-based uploads with automatic encoding
- `FormUploadingTask` - For form-encoded uploads
- `MIMEUploadingTask` - For multipart MIME uploads
- `EchoingTask` - Marker protocol that enables full console logging and recording for a task
- `NonEchoingTask` - Marker protocol that disables logging for a task (useful for sensitive operations)
- `IgnoredResultsTask` - For tasks where the response data is not needed

### Echo/Logging System
- Tasks can control logging via `echoStyle` property which returns a `TaskEchoStyle` option set
- Echo styles: `.consoleMinimum`, `.consoleRequest`, `.consoleFull`, `.console5k`/`.console10k`/`.console30k`/`.console100k` (limited output), `.recorded` (persist to disk), `.onlyIfError`
- By default, tasks have `.recorded` style
- Conforming to `EchoingTask` enables `[.consoleFull, .recorded]`
- Conforming to `NonEchoingTask` disables all logging
- Can override `echoStyle(for data: Data?)` to conditionally control logging based on response data

## Common Task Patterns

### Basic GET Request
```swift
struct FetchUserTask: ServerTask {
    let userId: String
    var path: String { "users/\(userId)" }
}

// Usage:
let task = FetchUserTask(userId: "123")
let data = try await task.download()
```

### POST with JSON
```swift
struct CreateUserTask: JSONUploadingTask {
    struct Payload: Codable { let name: String, email: String }

    var path: String { "users" }
    var method: HTTPMethod { .post }
    var uploadPayload: Payload?

    init(name: String, email: String) {
        self.uploadPayload = Payload(name: name, email: email)
    }
}
```

### Task with Custom Headers
```swift
struct AuthenticatedTask: ServerTask {
    var path: String { "profile" }

    var headers: Headers {
        get async throws {
            var headers = try await server.headers(for: self)
            headers.append(Header(name: "Authorization", value: "Bearer \(token)"))
            return headers
        }
    }
}
```

### Query Parameters
```swift
struct SearchTask: ServerTask {
    let query: String
    var path: String { "search" }
    var queryParameters: [String: String]? { ["q": query, "limit": "10"] }
}
```

### Task Execution
```swift
// Execute task and get decoded response
let response = try await task.download()
let payload = response.payload
let statusCode = response.statusCode
let duration = response.duration

// Execute task without caring about response
try await task.send()
```

### Form Upload
```swift
struct FormUploadTask: FormUploadingTask {
    var path: String { "submit" }
    var method: HTTPMethod { .post }
    var uploadPayload: [String: String]? { ["field1": "value1", "field2": "value2"] }
}
```

### Multipart MIME Upload
```swift
struct FileUploadTask: MIMEUploadingTask {
    var path: String { "upload" }
    var method: HTTPMethod { .post }
    var uploadPayload: MIMEPayload? {
        MIMEPayload(parts: [
            MIMEPart(name: "file", data: fileData, filename: "photo.jpg", mimeType: "image/jpeg"),
            MIMEPart(name: "description", stringValue: "My photo")
        ])
    }
}
```