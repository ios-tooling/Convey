# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Convey is a Swift Package Manager library for iOS, macOS, tvOS, visionOS, and watchOS that simplifies complex HTTP network operations. It provides a server-task architecture for managing network communications with built-in caching, error handling, and SwiftUI integration.

## Development Commands

### Building and Testing
- **Build**: `swift build`
- **Test**: `swift test` 
- **Build in Xcode**: Open `ConveyTest.xcodeproj` or `ConveyTestHarness.xcodeproj`
- **Single test**: `swift test --filter <TestName>`

### Project Structure
- **Main library**: `Sources/Convey/` - Core framework code
- **Test harness app**: `ConveyTestHarness/` - SwiftUI test application
- **Tests**: `Tests/ConveyTests/` - Unit tests
- **Package definition**: `Package.swift` - SPM configuration

## Architecture

### Core Components
- **ConveyServer**: Central server management class that handles remote connections, configuration, and session management. Subclass this for your app's server.
- **ServerTask**: Protocol-based task system for defining HTTP operations. Tasks are structs that conform to multiple protocols (GET, POST, etc.).
- **ServerConveyable**: Main protocol that all tasks implement, providing lifecycle hooks and configuration.

### Key Patterns
- **Actor-based concurrency**: Uses `@ConveyActor` for thread-safe operations
- **Protocol composition**: Tasks combine multiple protocols (e.g., `ServerGETTask`, `EchoingTask`) to define behavior
- **Configuration via Remote**: Environment switching through `Remote` objects for different endpoints

### Caching System
- **DataCache**: Actor-based caching with local-first, remote-first, and skip-local strategies
- **ImageCache**: Specialized image caching with SwiftUI integration via `CachedURLImage`
- **ETagStore**: HTTP ETag support for cache validation

### SwiftUI Integration
- **CachedURLImage**: Drop-in replacement for AsyncImage with caching
- **ConveyConsoleView**: Debug UI for monitoring network tasks
- **TaskReporterView**: UI for displaying task execution details

### Platform Support
- Minimum versions: iOS 14+, macOS 10.15+, watchOS 7+
- Swift 6.0+ required for concurrency features
- Uses system-zlib for compression

### Testing
- Unit tests focus on core functionality in `ConveyTests/`
- Test harness app provides integration testing with HTTPBin
- Test assets include image resources for caching tests