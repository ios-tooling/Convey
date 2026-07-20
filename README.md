# Convey

A modern, type-safe Swift networking framework for iOS, macOS, tvOS, watchOS, and visionOS. Built on Swift 6 concurrency with protocol-oriented architecture.

## Features

- **Protocol-oriented design** - Compose tasks from protocols with minimal boilerplate
- **Swift 6 concurrency** - Full async/await support, isolated to the `@ConveyActor` global actor
- **Type-safe networking** - Generic payloads with associated types
- **Comprehensive error handling** - All HTTP status codes (4xx, 5xx) with detailed error types
- **Automatic retries** - One `retryInterval` hook covering transport errors *and* throwing HTTP statuses (rate limits, server errors)
- **Built-in caching** - ETag store and image handling, with `CachedURLImage` for SwiftUI
- **Task recording** - SwiftData-based recording for debugging
- **Lifecycle hooks** - Optional hooks for request/response interception
- **Multi-environment** - Easy switching between dev/staging/prod
- **Streaming** - Server-sent events and streaming downloads

## Requirements

- Swift 6.0+
- iOS 14+, macOS 14+, watchOS 10+

## Installation

### Swift Package Manager

Add Convey to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ios-tooling/convey.git", from: "3.4.0")
]
```

Or in Xcode: File → Add Packages… → `https://github.com/ios-tooling/convey.git`

## Quick Start

### 1. Configure a Server

The simplest setup points the shared default server at your API:

```swift
import Convey

@ConveyActor func setUpNetworking() {
    ConveyServer.default.remote = Remote(URL(string: "https://api.myapp.com/v1")!, name: "Production")
    ConveyServer.default.configuration.defaultHeaders = ["X-API-Key": Secrets.apiKey]
}
```

For an isolated server (several APIs in one app, or a library that must not
touch the host app's default), conform to `ConveyServerable` — stored
`remote` and `configuration` are the only requirements; sessions, headers,
and URL building all have default implementations:

```swift
@ConveyActor final class MyServer: ConveyServerable {
    static let shared = MyServer()

    var remote = Remote(URL(string: "https://api.myapp.com/v1")!, name: "Production")
    var configuration = ServerConfiguration()
}
```

### 2. Define Tasks

Every task stores a `var configuration: TaskConfiguration?` (per-call
overrides); everything else defaults. `path` is appended to the server's
remote URL.

```swift
// GET returning raw Data
struct FetchAvatarTask: DataDownloadingTask {
    var configuration: TaskConfiguration?
    let userID: String
    var path: String { "users/\(userID)/avatar" }
}

// GET returning a decoded payload
struct FetchUserTask: DownloadingTask {
    typealias DownloadPayload = User      // any Decodable & Sendable

    var configuration: TaskConfiguration?
    let userID: String
    var path: String { "users/\(userID)" }
}

// POST with an Encodable JSON body
struct CreateUserTask: UploadingTask {
    typealias DownloadPayload = User

    struct Body: Codable, Sendable {
        let name: String
        let email: String
    }

    var configuration: TaskConfiguration?
    var uploadPayload: Body?
    var path: String { "users" }
    var method: HTTPMethod { .post }
}
```

### 3. Execute Tasks

```swift
// Typed download
let response = try await FetchUserTask(userID: "123").download()
let user = response.payload            // User
let status = response.statusCode       // 200

// Raw data
let data = try await FetchAvatarTask(userID: "123").downloadData().payload

// Fire and forget
try await CreateUserTask(uploadPayload: .init(name: "Alice", email: "alice@example.com")).send()
```

## Core Concepts

### Server Architecture

A server (anything conforming to `ConveyServerable`) owns the remote
environment, shared configuration, and session pooling. `ConveyServer.default`
is the implicit server for tasks that don't specify one.

```swift
public struct Remote {
    public init(_ url: URL, name: String, shortName: String? = nil)
}
```

**`ServerConfiguration` options** (the commonly used ones):

```swift
var defaultEncoder: JSONEncoder          // JSON encoding for uploads
var defaultDecoder: JSONDecoder          // JSON decoding for downloads
var defaultHeaders: Headers              // sent with every request
var userAgent: String?                   // defaults to app/device string
var defaultTimeout: TimeInterval         // 30s
var throwingStatusCategories: [Int]      // [400, 500] — status families that throw
var enableGZipDownloads: Bool            // true
var enableGZipUploads: Bool              // false
var redactedHeaders: Set<String>         // hidden in logs/recordings
var waitsForConnectivity: Bool
var allowsExpensiveNetworkAccess: Bool
var allowsConstrainedNetworkAccess: Bool
var requiredNetworkInterface: ConveyNetworkInterface?  // pin to wifi/cellular/…
```

**Server customization hooks** (defaults provided):

```swift
func headers(for task: any DownloadingTask) async throws -> Headers
func didFinish<T: DownloadingTask>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async
```

### Task Protocols

| Protocol | Payloads | Use for |
|---|---|---|
| `DownloadingTask<DownloadPayload>` | Decodable down | The base — typed GETs |
| `DataDownloadingTask` | `Data` down | Raw downloads |
| `UploadingTask<UploadPayload>` | Encodable up | JSON bodies from Codable types |
| `DataUploadingTask` | `Data` up/down | Pre-encoded bodies |
| `JSONUploadingTask` | dictionary up | Ad-hoc `json: [String: Sendable]?` bodies |
| `FormUploadingTask` | form up | `formFields: [String: Sendable]?`, URL-encoded |
| `MIMEUploadingTask` | multipart up | `mimeFields: [MIMEMessageComponent]?` |
| `SimpleGETTask` | `Data` | One-off GET of a full URL (concrete struct) |

**Marker protocols:** `EchoingTask` (full console logging + recording),
`NonEchoingTask` (no logging), `IgnoredResultsTask` (fire-and-forget).

**Commonly overridden task properties:**

```swift
var configuration: TaskConfiguration?              // stored; per-call overrides
var path: String                                   // appended to remote URL
var url: URL                                       // override for absolute URLs
var method: HTTPMethod                             // .get default
var headers: Headers { get async throws }          // added to server headers
var queryParameters: (any TaskQueryParameters)?    // [String: String] or [URLQueryItem]
var timeoutIntervalForRequest: TimeInterval?
var throwingStatusCategories: [Int]
var acceptType: String                             // Accept header, "*/*" default
var echoStyle: TaskEchoStyle
```

`TaskConfiguration` carries the same knobs per call: `timeout`, `headers`,
`cookies`, `echoStyle`, `gzip`, `queryParameters`, `throwingStatusCategories`,
`tags`, `redactedHeaders`.

### Lifecycle Hooks

Tasks can implement optional lifecycle methods:

```swift
// Inspect the outgoing request (throw to abort)
func willSendRequest(request: URLRequest) async throws

// Validate the raw response (throw to fail the task)
func didReceiveResponse(response: URLResponse, data: Data) async throws

// Handle completion
func didFinish(with response: ServerResponse<DownloadPayload>) async
func didFail(with error: any Error) async

// Control retry behavior — see Retry Logic below
func retryInterval(afterError error: any Error, count: Int) -> TimeInterval?
```

### Response Type

```swift
struct ServerResponse<Payload> {
    let payload: Payload                 // decoded response
    let data: Data                       // raw response bytes
    let request: URLRequest              // as sent
    let response: URLResponse
    var httpResponse: HTTPURLResponse?   // response, if HTTP
    var statusCode: Int
    var responseType: ResponseType       // .success, .clientError, .serverError…
    let startedAt: Date
    let duration: TimeInterval
    let attemptNumber: Int               // 1 unless retries happened
    let stringResult: String             // data as UTF-8, for debugging

    // Re-decode the same bytes as a different type
    func decoding<T: Decodable>(using decoder: JSONDecoder) throws -> ServerResponse<T>
}
```

## Error Handling

Statuses in `throwingStatusCategories` (default `[400, 500]` — the 4xx and
5xx families) throw a typed error conforming to `HTTPErrorType`:

```swift
public protocol HTTPErrorType: Sendable, LocalizedError {
    var statusCode: Int { get }
    var data: Data? { get }        // the error response body
}
```

```swift
do {
    let user = try await FetchUserTask(userID: id).download().payload
} catch let error as any HTTPErrorType {
    switch error.statusCode {
    case 401: await signIn()
    case 404: showMissingUser()
    default: showError(error.localizedDescription)   // includes body text
    }
}
```

Under the hood these are `HTTPError.ClientError` (one case per 4xx code) and
`HTTPError.ServerError` (one case per 5xx code), each carrying the response
data.

### Retry Logic

`retryInterval(afterError:count:)` is consulted for **transport errors and
for throwing HTTP statuses** — one hook covers flaky connections, rate
limits, and server hiccups. Return a delay to retry, or nil (the default) to
give up; `count` starts at 1 and increments per retry.

```swift
struct ResilientTask: DataDownloadingTask {
    var configuration: TaskConfiguration?
    var path: String { "data" }

    func retryInterval(afterError error: any Error, count: Int) -> TimeInterval? {
        guard count < 4 else { return nil }

        // Retry rate limits and server errors; give up on other statuses
        if let httpError = error as? any HTTPErrorType {
            guard httpError.statusCode == 429 || httpError.statusCode >= 500 else { return nil }
        }
        return pow(2.0, Double(count))    // 2s, 4s, 8s
    }
}
```

The final error is surfaced (thrown for transport errors, or the
`HTTPErrorType` for statuses) once the hook returns nil.

## Advanced Usage

### Custom Headers

Task headers are *added to* the server's headers — no need to merge manually:

```swift
struct AuthenticatedTask: DataDownloadingTask {
    var configuration: TaskConfiguration?
    let token: String
    var path: String { "profile" }

    var headers: Headers {
        get async throws { ["Authorization": "Bearer \(token)"] }
    }
}
```

### Query Parameters

```swift
struct SearchTask: DataDownloadingTask {
    var configuration: TaskConfiguration?
    let query: String
    let limit: Int

    var path: String { "search" }
    var queryParameters: (any TaskQueryParameters)? {
        ["q": query, "limit": "\(limit)"]
    }
}
```

### Form Upload

```swift
struct LoginTask: FormUploadingTask {
    var configuration: TaskConfiguration?
    let username: String
    let password: String

    var path: String { "auth/login" }
    var method: HTTPMethod { .post }
    var formFields: [String: Sendable]? {
        ["username": username, "password": password]
    }
}
```

### Multipart MIME Upload

```swift
struct UploadPhotoTask: MIMEUploadingTask {
    var configuration: TaskConfiguration?
    let imageData: Data
    let caption: String

    var path: String { "photos" }
    var method: HTTPMethod { .post }
    var mimeBoundary: String { String.createBoundary() }
    var mimeFields: [MIMEMessageComponent]? {
        [
            .fileData(contentType: "image/jpeg", data: imageData, filename: "photo.jpg"),
            .formData(fields: ["caption": caption]),
        ]
    }
}
```

Other components: `.text(content:)`, `.file(contentType:url:)`,
`.data(contentType:data:)`, `.image(name:image:quality:)`.

### Response Validation

```swift
struct ValidatedTask: DataDownloadingTask {
    var configuration: TaskConfiguration?
    var path: String { "data" }

    func didReceiveResponse(response: URLResponse, data: Data) async throws {
        guard let http = response as? HTTPURLResponse,
              http.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true else {
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
        case .dev: Remote(URL(string: "https://dev.api.com/v1")!, name: "Dev")
        case .staging: Remote(URL(string: "https://staging.api.com/v1")!, name: "Staging")
        case .prod: Remote(URL(string: "https://api.com/v1")!, name: "Production")
        }
    }
}

MyServer.shared.remote = Environment.staging.remote
```

### Logging and Debugging

`TaskEchoStyle` is an option set; tasks default to `[.recorded]`.

```swift
// Marker protocols
struct DebugTask: DataDownloadingTask, EchoingTask { … }     // [.consoleFull, .recorded]
struct QuietTask: DataDownloadingTask, NonEchoingTask { … }  // no logging

// Or pick styles explicitly
struct CustomLogTask: DataDownloadingTask {
    var configuration: TaskConfiguration?
    var path: String { "data" }
    var echoStyle: TaskEchoStyle { [.console5k, .recorded, .onlyIfError] }
}
```

Styles: `.consoleMinimum`, `.consoleRequest`, `.consoleFull`, `.console5k` /
`.console10k` / `.console30k` / `.console100k` (truncated bodies),
`.recorded` (SwiftData), `.onlyIfError`.

### SwiftUI Integration

```swift
import SwiftUI
import Convey

struct ProfileView: View {
    var body: some View {
        CachedURLImage(url: avatarURL, contentMode: .fill, placeholder: Image(systemName: "person"))
    }
}
```

### Task Recording

View recorded network tasks in SwiftUI with `RecordedTasksButton()` or by
presenting `RecordedTasksScreen()` directly.

### Session Management

```swift
// Cancel in-flight tasks
await MyServer.shared.cancelTasks(ofType: FetchUserTask.self)
await MyServer.shared.cancelTasks(with: [requestID])
```

## Testing Support

Convey's tests use the Swift Testing framework:

```swift
import Testing
import Convey

@Suite("API Tests")
struct APITests {
    @Test("Fetch user data")
    func fetchUser() async throws {
        let response = try await FetchUserTask(userID: "123").download()
        #expect(response.statusCode == 200)
    }
}
```

Because the test target mixes XCTest and Swift Testing, run the full suite
with `swift test --enable-swift-testing`.

### Debug Mode

Run with the `-fail-all-requests` command line argument to make all requests
fail immediately (useful for testing error handling).

## Architecture

Convey uses a server-task architecture:

- **ConveyServerable / ConveyServer** - Remote environment, configuration, session pooling
- **Tasks** - Protocol-based definitions of HTTP operations
- **ConveyActor** - Global actor ensuring thread-safe execution
- **ConveySession** - Per-request session handling with pooling and retries
- **ServerResponse** - Generic response wrapper with decoded payload

## Privacy

Convey does not collect any data. This notice helps you fill out [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

## Documentation

See [CLAUDE.md](CLAUDE.md) for comprehensive framework documentation and implementation details.

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please open an issue or pull request on GitHub.
