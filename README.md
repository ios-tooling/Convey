# Convey

A modern, type-safe Swift networking framework for iOS, macOS, tvOS, watchOS, and visionOS. Built on Swift 6 concurrency with protocol-oriented architecture.

## Features

- **Protocol-oriented design** - Compose tasks from protocols with minimal boilerplate
- **Swift 6 concurrency** - Full async/await support with actor-based thread safety
- **Type-safe networking** - Generic payloads with associated types
- **Comprehensive error handling** - All HTTP status codes (4xx, 5xx) with detailed error types
- **Built-in caching** - Image and data caching with ETag support
- **SwiftUI integration** - CachedURLImage view and debug screens
- **Task recording** - SwiftData-based recording for debugging
- **Lifecycle hooks** - Optional hooks for request/response interception
- **Automatic retries** - Configurable retry logic with custom intervals
- **Multi-environment** - Easy switching between dev/staging/prod
- **Zero dependencies** - Only JohnnyCache for caching implementation

## Requirements

- Swift 6.0+
- iOS 14+, macOS 14+, watchOS 7+, tvOS 14+, visionOS 1.0+

## Installation

### Swift Package Manager

Add Convey to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ios-tooling/convey.git", from: "1.3.0")
]
```

Or in Xcode:
1. File → Add Packages...
2. Enter: `https://github.com/ios-tooling/convey.git`

## Quick Start

### 1. Create a Server

```swift
import Convey

class MyServer: ConveyServer {
    static let shared = MyServer()

    init() {
        super.init(asDefault: true)

        // Configure environments
        self.remote = Remote(
            url: URL(string: "https://api.myapp.com")!,
            commonPath: "v1"
        )
    }
}
```

### 2. Define Tasks

```swift
// Simple GET request
struct FetchUserTask: DataDownloadingTask {
    let userId: String
    var path: String { "users/\(userId)" }
}

// POST with JSON payload
struct CreateUserTask: JSONUploadingTask {
    struct Payload: Codable {
        let name: String
        let email: String
    }

    var path: String { "users" }
    var method: HTTPMethod { .post }
    var uploadPayload: Payload?

    init(name: String, email: String) {
        self.uploadPayload = Payload(name: name, email: email)
    }
}
```

### 3. Execute Tasks

```swift
// Get response with payload
let task = FetchUserTask(userId: "123")
let response = try await task.download()
let userData = response.payload
let statusCode = response.statusCode

// Fire and forget
try await CreateUserTask(name: "Alice", email: "alice@example.com").send()
```

## Core Concepts

### Server Architecture

`ConveyServer` is the central class managing remote connections, configuration, and session management.

**Key Properties:**

```swift
var remote: Remote                      // Environment configuration
var configuration: ServerConfiguration  // Global settings
var disabled: Bool                      // Fail all tasks immediately
```

**Configuration Options:**

```swift
var defaultEncoder: JSONEncoder         // JSON encoding
var defaultDecoder: JSONDecoder         // JSON decoding
var throwingStatusCategories: [Int]     // [400, 500] by default
var enableGZipDownloads: Bool           // Compression
var defaultTimeout: TimeInterval        // Request timeout
var allowsExpensiveNetworkAccess: Bool  // Cellular access
var allowsConstrainedNetworkAccess: Bool // Low data mode
var waitsForConnectivity: Bool          // Wait for connection
var userAgent: String?                  // Custom user agent
var defaultHeaders: [String: String]    // Common headers
```

**Server Customization Hooks:**

```swift
// Add custom headers per task
func headers(for task: DownloadingTask) async throws -> Headers

// Called after every task completion
func didFinish(task: DownloadingTask, response: ServerResponse?, error: Error?)
```

### Task Protocols

Tasks are structs conforming to protocol compositions:

#### Base Protocol

```swift
protocol DownloadingTask<DownloadPayload>
```

All tasks conform to this. Default implementations minimize boilerplate.

#### Specialized Task Types

**DataDownloadingTask** - downloads raw Data

**UploadingTask** - Adds upload capabilities:
- `JSONUploadingTask` - JSON encoding
- `FormUploadingTask` - Form encoding
- `DataUploadingTask` - Raw data upload
- `MIMEUploadingTask` - Multipart MIME

**Marker Protocols:**
- `EchoingTask` - Enable full console logging + recording
- `NonEchoingTask` - Disable all logging
- `IgnoredResultsTask` - Fire-and-forget tasks

#### Task Properties

```swift
var path: String                        // Relative path from remote URL
var method: HTTPMethod                  // .get, .post, .put, .patch, .delete
var server: ConveyServerable            // Defaults to ConveyServer.default
var queryParameters: [String: String]?  // URL query params
var headers: Headers                    // Custom headers
var decoder: JSONDecoder                // Override default decoder
var timeout: TimeInterval?              // Override default timeout
var echoStyle: TaskEchoStyle            // Logging configuration
```

### Lifecycle Hooks

Tasks can implement optional lifecycle methods:

```swift
// Modify request before sending
func willSendRequest(request: URLRequest) async throws -> URLRequest

// Validate response (can throw to fail task)
func didReceiveResponse(response: HTTPURLResponse, data: Data) async throws

// Handle success
func didFinish(with response: ServerResponse<DownloadPayload>) async throws

// Handle failure
func didFail(with error: Error) async throws

// Control retry behavior
func retryInterval(afterError error: Error, count: Int) async -> TimeInterval?
```

### Response Type

```swift
struct ServerResponse<Payload> {
    let payload: Payload                // Decoded response
    let data: Data                      // Raw response data
    let httpResponse: HTTPURLResponse   // Full HTTP response
    let request: URLRequest             // Original request
    let statusCode: Int                 // HTTP status code
    let responseType: ResponseType      // .success, .clientError, etc.
    let duration: TimeInterval          // Request duration
    let attempt: Int                    // Retry attempt number

    // Re-decode to different type
    func decoding<T: Decodable>(using decoder: JSONDecoder) throws -> ServerResponse<T>
}
```

### Error Handling

Convey provides comprehensive HTTP error types:

```swift
// Client errors (4xx)
HTTPError.ClientError.badRequest        // 400
HTTPError.ClientError.unauthorized      // 401
HTTPError.ClientError.forbidden         // 403
HTTPError.ClientError.notFound          // 404
// ... and 18 more specific client errors

// Server errors (5xx)
HTTPError.ServerError.internalServer    // 500
HTTPError.ServerError.badGateway        // 502
HTTPError.ServerError.serviceUnavailable // 503
// ... and 8 more specific server errors
```

Each error includes:
- Status code
- Response data
- Localized description

Configure which status codes throw:

```swift
server.configuration.throwingStatusCategories = [400, 500] // Default
```

### Retry Logic

Implement automatic retries:

```swift
struct ResilientTask: DataDownloadingTask {
    var path: String { "data" }

    func retryInterval(afterError error: Error, count: Int) async -> TimeInterval? {
        guard count < 3 else { return nil } // Max 3 attempts
        return pow(2.0, Double(count))      // Exponential backoff: 2s, 4s, 8s
    }
}
```

## Advanced Usage

### Custom Headers

```swift
struct AuthenticatedTask: DataDownloadingTask {
    let token: String
    var path: String { "profile" }

    var headers: Headers {
        get async throws {
            var headers = try await server.headers(for: self)
            headers.append(header: "Authorization", value: "Bearer \(token)")
            return headers
        }
    }
}
```

### Query Parameters

```swift
struct SearchTask: DataDownloadingTask {
    let query: String
    let limit: Int

    var path: String { "search" }
    var queryParameters: [String: String]? {
        ["q": query, "limit": "\(limit)"]
    }
}
```

### Form Upload

```swift
struct LoginTask: FormUploadingTask {
    var path: String { "auth/login" }
    var method: HTTPMethod { .post }
    var uploadPayload: [String: String]? {
        ["username": username, "password": password]
    }
}
```

### Multipart MIME Upload

```swift
struct UploadPhotoTask: MIMEUploadingTask {
    let imageData: Data
    let caption: String

    var path: String { "photos" }
    var method: HTTPMethod { .post }
    var uploadPayload: MIMEPayload? {
        MIMEPayload(parts: [
            MIMEPart(name: "photo", data: imageData,
                    filename: "photo.jpg", mimeType: "image/jpeg"),
            MIMEPart(name: "caption", stringValue: caption)
        ])
    }
}
```

### Response Validation

```swift
struct ValidatedTask: DataDownloadingTask {
    var path: String { "data" }

    func didReceiveResponse(response: HTTPURLResponse, data: Data) async throws {
        // Custom validation
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("application/json") else {
            throw ValidationError.invalidContentType
        }
    }
}
```

### Environment Switching

```swift
enum Environment {
    case dev, staging, prod

    var remote: Remote {
        switch self {
        case .dev:
            return Remote(url: URL(string: "https://dev.api.com")!, commonPath: "v1")
        case .staging:
            return Remote(url: URL(string: "https://staging.api.com")!, commonPath: "v1")
        case .prod:
            return Remote(url: URL(string: "https://api.com")!, commonPath: "v1")
        }
    }
}

// Switch environments
MyServer.shared.remote = Environment.staging.remote
```

### Logging and Debugging

Control logging per task or globally:

```swift
// Task-level control
struct DebugTask: DataDownloadingTask, EchoingTask {
    var path: String { "debug" }
    // Enables full console logging + recording
}

// Or use echoStyle property
struct CustomLogTask: DataDownloadingTask {
    var path: String { "data" }
    var echoStyle: TaskEchoStyle { [.consoleFull, .recorded] }
}

// Echo styles:
// .consoleMinimum  - Basic logging
// .consoleFull     - Full request/response
// .console5k       - First 5KB of response
// .recorded        - Save to disk (SwiftData)
// .onlyIfError     - Only log failures
```

### SwiftUI Integration

```swift
import SwiftUI
import Convey

struct ProfileView: View {
    var body: some View {
        CachedURLImage(
            url: URL(string: "https://example.com/avatar.jpg")!,
            cache: .imageCache
        ) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "exclamationmark.triangle")
            @unknown default:
                EmptyView()
            }
        }
    }
}
```

### Task Recording

View recorded network tasks in SwiftUI:

```swift
import SwiftUI
import Convey

struct DebugView: View {
    var body: some View {
        RecordedTasksButton()
    }
}
```

Or present the screen directly:

```swift
RecordedTasksScreen()
```

### Caching

```swift
// Image caching (automatic with CachedURLImage)
let cache = ImageCache.shared

// Data caching
let dataCache = DataCache()
await dataCache.cache(data, for: url, cacheStyle: .localFirst)
let cachedData = await dataCache.fetch(for: url)

// Cache styles:
// .localFirst   - Use local cache if available
// .remoteFirst  - Always check remote first
// .skipLocal    - Bypass cache
```

### Session Management

```swift
// Cancel specific sessions by tag
ConveySession.cancel(sessionWithTag: "background-sync")

// Disable server to fail all requests
MyServer.shared.disabled = true
```

## Testing Support

Convey uses Swift Testing framework (not XCTest):

```swift
import Testing
import Convey

@Suite("API Tests")
struct APITests {
    @Test("Fetch user data")
    func testFetchUser() async throws {
        let task = FetchUserTask(userId: "123")
        let response = try await task.download()
        #expect(response.statusCode == 200)
    }
}
```

### Debug Mode

Run with `-fail-all-requests` command line argument to make all requests fail immediately (useful for testing error handling).

## Architecture

Convey uses a server-task architecture:

- **ConveyServer** - Manages remote connections, configuration, and sessions
- **Tasks** - Protocol-based definitions of HTTP operations
- **ConveyActor** - Global actor ensuring thread-safe execution
- **ConveySession** - Individual session management with pooling
- **ServerResponse** - Generic response wrapper with decoded payload

### Concurrency Model

- All core types marked with `@ConveyActor` for data race safety
- Custom `ConveyThreadsafeMutex` for low-level synchronization
- URLSession pooling with thread-safe lifecycle management
- Full async/await throughout

## Privacy

Convey does not collect any data. This notice helps you fill out [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

## Documentation

See [CLAUDE.md](CLAUDE.md) for comprehensive framework documentation and implementation details.

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please open an issue or pull request.
