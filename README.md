# Convey

Convey is a cross-platform library for iOS, macOS, tvOS, visionOS for easily managing complex HTTP network operations.

## Installing Convey
Convey supports [Swift Package Manager](https://www.swift.org/package-manager/).

### Github Repo

You can pull the [Convey Github Repo](https://github.com/ios-tooling/convey/) here.

### Swift Package Manager

To install Convey using [Swift Package Manager](https://github.com/apple/swift-package-manager) you can follow the [tutorial published by Apple](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app) using the URL for the Convey repo with the current version:

1. In Xcode, select “File” → “Add Packages...”
1. Enter https://github.com/ios-tooling/convey.git

or you can add the following dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/ios-tooling/convey.git", from: "1.3.0")
```


### Data collection

Convey does not collect any data. We provide this notice to help you fill out [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

### Usage

Convey is built around two fundamental data types: Servers and ServerTasks. A server represents the remote side of any HTTP connection, while a task is any self-contained communication with a Server.

To get started, you'll want to subclass ConveyServer and create a singleton instance of it. Every Server should have a `Remote` assigned to it to let it know its remote URL. You can create multiple `Remote` objects, each representing a different environment (dev, staging, prod, etc) and switch between them. Each remote contains the URL of the actual server instance you're connecting too, as well as any common paths (e.g. `https://myserver.com/api/v1/`)

It's recommended that you setup your server early in your launch process, and assign a `Remote` then. 

# Server

`init(asDefault: Bool = true)`

- when creating a server, if you specify it as default, then any Task that doesn't specify a `server` property will treat this as its server (useful for situations where you are communicating with multiple remotes)

`var remote: Remote`				

- the remote URL information for this server

`var defaultEncoder: JSONEncoder`	

- the default JSON encoder to use for uploads

`var defaultDecoder: JSONDecoder`	

- the default JSON decoder to use for downloads

`var reportBadHTTPStatusAsError: Bool`

- if a non-200 is receive from the server, should an error be thrown?

`var configuration: URLSessionConfiguration`

- the default URLConfiguration to use when creating a new URLSession

`var enableGZipDownloads: Bool`

- should we request GZip encoding from the server

`var defaultTimeout: TimeInterval`

- what's the default timeout for the server, for both resource and request timeouts

`var allowsExpensiveNetworkAccess: Bool`

- should tasks on this server use 'expensive' networks, such as cellular

`var allowsConstrainedNetworkAccess: Bool`

- should tasks on this server run in 'low data' mode

`var waitsForConnectivity: Bool`

- should URLSession wait for a remote connection when running, or fail immediately if there isn't one

`var logStyle: ConveyTaskManager.LogStyle`

- can be `none`, `short`, or `steps`. Controls how much data about active tasks is logged to the console.

`var taskPathURL: URL?`

- if you want to log all tasks to disk, set the directory to store them here. Use `recordTaskPath(to: URL)` to start recording, and `endTaskPathRecording()` to end.

`var disabled: Bool`

- if set, all tasks using this server will fail immediately

`var userAgent: String?`

- set the user agent to override with. By default, it uses `defaultUserAgent`

`var maxLoggedDownloadSize: Int`

- when logging downloads, how much data should we show before just using a placeholder

`var maxLoggedUploadSize: Int`

- when logging uploads, how much data should we show before just using a placeholder

`func register(publicKey: String, for server: String)`

- if using server pinning, you can set the key for a given host here.

`func setStandardHeaders([String: String])`

- if using static headers for all requests, set them here

`func standardHeaders(for task: ServerTask) async throws -> [String: String]`

- if using per-request headers, override this.

`func preflight(_ task: ServerTask, request: URLRequest) async throws -> URLRequest`

- to generate a custom URLRequest for a given task, override this.



# ServerTask

Server tasks are structs that conform to multiple protocols. They have a few properties that may be implemented:

`var path: String`

- most tasks will implement this, and it's the relative path based off their `server`'s remote URL.

`var server: ConveyServer`

- for single-Server apps, this can be omitted, as it defaults to the default server. In apps with multiple remote servers, the task will need to specify which server to use if it's not the default.

`var httpMethod: String`

- this is usually specified by a particular protocol, such as `ServerPOSTTask`. If a non-standard protocol is required, it can be specified here.

`var url: URL`

- this is normally derived from the `path` and `server` properties, and can be omitted.

`var taskTag: String`

- if a task needs to be uniquely identified, a taskTag can be provided.

`func postProcess(response: ServerReturned) async throws`

- if the task needs to execute code after its finished communicating, then a `postProcess(:)` function can be provided

## Useful Protocols

A task should conform to multiple protocols to define its behavior.

`ServerGETTask`, `ServerPOSTTask` `ServerPATCHTask`, `ServerPUTTask`, `ServerDELETETask`

- a task should conform to one of these to specify the HTTP method. If none are conformed to, than GET is assumed. Providing a `httpMethod` var for a task will supersede this.

`EchoingTask`

- a task conforming to this will have its upload and download data (including headers, payload, etc) logged to the console.

 








