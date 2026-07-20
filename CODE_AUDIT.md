# Convey Code Audit

Generated 2026-07-20. Scope: approximately 7,455 lines across 90 Swift files in the `Convey` package, package tests, and the test-harness application. Build products, package checkouts, and other third-party dependency internals were excluded.

Findings cite `path:line` so each item can be opened directly. The initial audit was read-only; remediation statuses below reflect the follow-up changes made on 2026-07-20.

---

## 1. Executive summary

The original top ten, all addressed on 2026-07-20:

1. **[Resolved — Critical] Count-based task retention can crash** — §5.1 — `Sources/Convey/TaskRecording/ModelContext.swift:50-57`. The closed range indexes past the array for `.count(0)` and always deletes one record too many.
2. **[Resolved — High] Targeted cancellation can cancel unrelated requests** — §3.1 — `Sources/Convey/Utility/ConveySession.swift:63-80`. Matching requests share a `URLSession`, while cancelling one invalidates the shared session.
3. **[Resolved — High] Unknown 4xx/5xx responses can be treated as successes** — §5.2 — `Sources/Convey/Errors/HTTPError.swift:29-42`. Failable specialized initializers return `nil` instead of falling back to an unknown HTTP error.
4. **[Resolved — High] Decode failures are recorded as successful completion** — §5.3 — `Sources/Convey/Tasks/DownloadingTask+Download.swift:61-84,141-150`. Persistence and server success callbacks occur before typed decoding.
5. **[Resolved — High] Request hooks cannot modify the transmitted request** — §5.6 — `Sources/Convey/Tasks/DownloadingTask.swift:38-41`. `willSendRequest` receives an immutable value after the session captured it.
6. **[Resolved — High] Header layering combines singleton headers** — §5.7 — `Sources/Convey/Tasks/DownloadingTask+Request.swift:35-42`. Task headers do not reliably override server headers.
7. **[Resolved — High/Security] Recording can persist secrets outside headers** — §6.1 — `Sources/Convey/TaskRecording/TaskRecordingInfo+Chronicle.swift:27-35`. URLs, bodies, errors, and recoverable task state lack field-level redaction.
8. **[Resolved — High] Image sizing accepts oversized images and rejects smaller ones** — §5.9 — `Sources/Convey/Caching/ImageSizing.swift:122-135`. Several comparisons are inverted or use the wrong dimension.
9. **[Resolved — High] `CachedURLImage` can launch duplicate work and show stale images** — §8.1 — `Sources/Convey/UI/CachedURLImage.swift:51-91`. Fetching is a side effect of view rendering and is not tied to URL cancellation.
10. **[Resolved — High] The test-harness project cannot resolve Convey** — §9.1 — `Test Harness/ConveyTestHarness.xcodeproj/project.pbxproj:614-618`. Its local package path resolves to a nonexistent nested directory.

Overall assessment: the package has a strong actor-oriented foundation and the clean package build succeeds, but cancellation ownership, lifecycle ordering, request configuration precedence, recording privacy, and image utilities need focused correction before relying on the more advanced APIs in production.

## 2. Quick wins (≤30 min each)

### 2.1 Remove the clean-build deprecation warning
- **Location:** `Sources/Convey/UI/CachedURLImage.swift:89-91`
- **What:** Replace the deprecated one-parameter `onChange` overload while restructuring the image task described in §8.1.
- **Why:** This is the only unique warning emitted by a clean package build.
- **Action:** Use the current zero- or two-parameter overload, subject to the package's deployment-target compatibility needs.
- **Severity:** Low

### 2.2 Exclude intentionally disabled tests from the package target
- **Location:** `Package.swift:29`; `Tests/ConveyTests/MIMETests.swift.disabled`; `Tests/ConveyTests/StringTests.swift.disabled`; `Tests/ConveyTests/TaskTests.swift.disabled`
- **What:** SwiftPM reports the three disabled files as unhandled on every test run.
- **Why:** Repeated warnings obscure new build diagnostics.
- **Action:** Add explicit exclusions or move archived tests outside the target directory.
- **Severity:** Low

### 2.3 Remove obsolete commented UI branches
- **Location:** `Sources/Convey/UI/RecordedTasksScreen.swift:71-86`; `Sources/Convey/UI/RecordedTaskDetailScreen.swift:21-26`; `Test Harness/ConveyTestHarness/HTTPBin.swift:38-46`
- **What:** Entire alternate implementations remain commented out, including a toolbar and attributed editor.
- **Why:** They obscure the active UI and make unfinished behavior appear intentional.
- **Action:** Delete them or restore them as tested features tracked by an issue.
- **Severity:** Low

### 2.4 Replace scattered operational `print` calls
- **Location:** `Sources/Convey/Caching/FileWatcher.swift:27-32`; `Sources/Convey/TaskRecording/TaskRecorder.swift:69-89`; `Sources/Convey/UI/RecordedTasksScreen+Tabs.swift:29-55`
- **What:** Persistence and file failures are printed while the package otherwise depends on Chronicle.
- **Why:** Library clients cannot route, redact, or observe console-only failures consistently.
- **Action:** Use the configurable logging path and preserve structured failure state when correctness is affected.
- **Severity:** Low

## 3. Concurrency

### 3.1 Cancelling one request can invalidate unrelated requests
- **Status (2026-07-20): Addressed.** Each `ConveySession` now owns its `URLSession`, and idempotent finish/cancel paths invalidate only that request's transport.
- **Location:** `Sources/Convey/Utility/ConveySession.swift:63-80`; `Sources/Convey/Server/ConveyServable.swift:38-47`
- **What:** Matching `ConveySession` wrappers reuse the same `URLSession`, but targeted cancellation calls `invalidateAndCancel()` on that shared object.
- **Why:** Cancelling by request ID or task type can abort unrelated concurrent requests that happen to share the configuration.
- **Action:** Own and cancel the individual `URLSessionTask`, or stop sharing invalidatable sessions between request wrappers.
- **Severity:** High

### 3.2 Required-interface requests ignore structured cancellation
- **Location:** `Sources/Convey/Utility/NetworkInterfaceHTTPClient.swift:24-31,35-43,78-92`
- **What:** The continuation-based `NWConnection` bridge has no task cancellation handler.
- **Why:** Cancelling the awaiting Swift task can leave the socket active and the caller suspended until timeout or network completion.
- **Action:** Couple parent-task cancellation to race-safe connection cancellation and exactly-once continuation resumption.
- **Severity:** High

### 3.3 Recovery sweeps can execute the same persisted task concurrently
- **Location:** `Sources/Convey/TaskRecording/TaskRecorder.swift:32-39`; `Sources/Convey/TaskRecording/StorableTask.swift:32-42`; `Sources/Convey/TaskRecording/TaskRecovery.swift:22-25`; `Sources/Convey/TaskRecording/TaskRecovery+Retry.swift:34-49`
- **What:** App activation and registration can start overlapping retry sweeps, and records are not atomically marked in-flight before an awaited request.
- **Why:** Actor reentrancy permits the same pending non-idempotent task to be submitted more than once.
- **Action:** Coalesce sweeps and atomically claim records with in-flight/backoff state before leaving actor isolation.
- **Severity:** High

### 3.4 Payload work is serialized on the global network actor
- **Location:** `Sources/Convey/Tasks/DownloadingTask.swift:11-44`; `Sources/Convey/Tasks/DownloadingTask+Request.swift:28-57`; `Sources/Convey/Tasks/DownloadingTask+Download.swift:60-78`
- **What:** Synchronous JSON inspection, encoding, gzip, MIME construction, and decoding all execute under `@ConveyActor`.
- **Why:** Large payload CPU work can head-of-line block unrelated request setup and server bookkeeping.
- **Action:** Keep mutable coordination actor-isolated while processing immutable `Sendable` payload snapshots outside the global actor.
- **Severity:** Medium

## 4. API modernity

### 4.1 `CachedURLImage` uses a deprecated SwiftUI API
- **Location:** `Sources/Convey/UI/CachedURLImage.swift:89-91`
- **What:** `onChange(of:perform:)` is deprecated on the package's macOS 14 deployment target.
- **Why:** It emits the clean-build compiler warning.
- **Action:** Adopt the current overload as part of the §8.1 lifecycle repair.
- **Severity:** Low

### 4.2 Server connectivity controls are not applied
- **Location:** `Sources/Convey/Configuration/ServerConfiguration.swift:24-32`; `Sources/Convey/Utility/ConveySession.swift:53-61`
- **What:** `allowsExpensiveNetworkAccess`, `allowsConstrainedNetworkAccess`, and `waitsForConnectivity` are never copied from the server configuration into the session configuration.
- **Why:** Public settings silently have no effect; notably, Convey defaults `waitsForConnectivity` to true while `URLSessionConfiguration.default` does not inherit that value from Convey.
- **Action:** Apply server values before per-task overrides and test the resulting configuration.
- **Severity:** High

### 4.3 Several public configuration properties have no implementation
- **Location:** `Sources/Convey/Configuration/ServerConfiguration.swift:25-39`
- **What:** `enableGZipDownloads`, `maxLoggedUploadSize`, `pinExpiredToleranceInDays`, and `enableTaskLoggingAtLaunch` have no end-to-end behavior matching their names.
- **Why:** Consumers can rely on apparent compression, logging-limit, pinning, or launch behavior that never occurs.
- **Action:** Implement and test each property or deprecate/remove it until supported.
- **Severity:** Medium

### 4.4 Default task configuration is never merged
- **Location:** `Sources/Convey/Server/ConveyServable.swift:10-20,32-36,82-87`; `Sources/Convey/Configuration/TaskConfiguration.swift:82-97`
- **What:** `defaultTaskConfiguration` and `merged(with:)` have no production callers.
- **Why:** Server-wide task defaults appear supported but do not influence headers, timeouts, gzip, tags, or redaction.
- **Action:** Merge server and task configuration at one documented boundary with explicit precedence tests.
- **Severity:** Medium

### 4.5 Codable task configuration silently drops fields
- **Location:** `Sources/Convey/Configuration/TaskConfiguration.swift:11-23,42-79`
- **What:** `cookies` and `queryParameters` are not represented in `CodingKeys` or encoded/decoded.
- **Why:** A public `Codable` round trip does not preserve the complete configuration value.
- **Action:** Define serializable representations for supported fields or document and enforce that they are intentionally transient.
- **Severity:** Medium

## 5. Bugs / logic errors

### 5.1 Count-based retention can crash and deletes too many records
- **Status (2026-07-20): Addressed.** Retention clamps negative values and deletes the exact oldest prefix using `prefix(_:)`; regression coverage includes limits of two and zero.
- **Location:** `Sources/Convey/TaskRecording/ModelContext.swift:50-57`
- **What:** The closed range `0...(all.count - count)` deletes one extra element and indexes `all[all.count]` for `.count(0)`.
- **Why:** A valid-looking public retention setting can trap the process; positive limits retain one fewer item than requested.
- **Action:** Reject negative limits and delete exactly the required prefix using half-open bounds or collection slicing.
- **Severity:** Critical

### 5.2 Unknown 4xx and 5xx statuses bypass error handling
- **Status (2026-07-20): Addressed.** Unlisted client/server codes now fall back to `UnknownError`; status 599 is covered by a regression test.
- **Location:** `Sources/Convey/Errors/HTTPError.swift:29-42`; `Sources/Convey/Errors/ClientError.swift:42-74`; `Sources/Convey/Errors/ServerError.swift:24-38`
- **What:** The 400/500-family branches directly return failable enum initializers, so unlisted codes such as 419 or 599 produce no error.
- **Why:** Responses in categories explicitly configured to throw can be decoded and handled as successes.
- **Action:** Fall back to `UnknownError` when the specialized initializer returns `nil`.
- **Severity:** High

### 5.3 Decode failures bypass lifecycle failure handling
- **Status (2026-07-20): Addressed.** Transform/decoding now completes before success persistence or server notification, and failures flow through task, server, and observer hooks once.
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Download.swift:61-84,141-150`
- **What:** `performDownload` marks the record complete and reports server success before typed decoding; a decode error only reaches `TaskObserver`.
- **Why:** Task `didFail`, server error hooks, and recoverable-task state contradict the error returned to the caller.
- **Action:** Finalize persistence and server success only after decoding, and route decode failures through the unified failure lifecycle.
- **Severity:** High

### 5.4 Failed downloads notify observers twice
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Download.swift:60-84,151-172`
- **What:** `performDownload` notifies `TaskObserver.didFail` before rethrowing, then `download(usingRecordedTaskID:)` catches the same error and notifies again.
- **Why:** UI actions, analytics, or recovery logic registered as observers can run twice for one failure.
- **Action:** Centralize observer completion and failure notification at one layer and test exact callback counts.
- **Severity:** High

### 5.5 Multiple observing views replace one another
- **Location:** `Sources/Convey/UI/View+TaskObserving.swift:15-22,31-38`; `Sources/Convey/TaskRecording/TaskObserver.swift:71-94`
- **What:** Every modifier instance registers from the same internal file/function/line, while the registry treats that call-site tuple as unique and replaces the existing observer.
- **Why:** Only the most recently appeared view using an overload can continue receiving callbacks; another view's disappearance can also unregister unexpected state.
- **Action:** Give each modifier instance a stable unique identity and let the registry support multiple observers for the same source call site.
- **Severity:** High

### 5.6 `willSendRequest` cannot modify the request
- **Status (2026-07-20): Addressed.** A source-compatible request-returning overload now supplies the actual buffered and streaming request sent by the session.
- **Location:** `Sources/Convey/Tasks/DownloadingTask.swift:38-41,80-83`; `Sources/Convey/Utility/ConveySession.swift:42-47`; `Sources/Convey/Tasks/DownloadingTask+Download.swift:123-132`
- **What:** The hook receives `URLRequest` by value and returns nothing after the session has captured an immutable request.
- **Why:** Documented signing, header, URL, or body modifications cannot affect the request that is sent.
- **Action:** Return the modified request or accept an inout request before session/task creation; otherwise rename the hook as validation-only.
- **Severity:** High

### 5.7 Header layering appends instead of overriding
- **Status (2026-07-20): Addressed.** Server, task-configuration, and task layers use ordered `setValue` semantics, with task values winning case-insensitively.
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Request.swift:35-42`; `Sources/Convey/Utility/Headers.swift:21-34`
- **What:** Server and task headers are concatenated and applied using `addValue`, including duplicate case-insensitive names.
- **Why:** Singleton fields such as `Authorization`, `Content-Type`, `Host`, and `User-Agent` can become invalid comma-combined values instead of honoring task precedence.
- **Action:** Resolve layers case-insensitively with documented precedence; preserve multiplicity only for headers that permit it.
- **Severity:** High

### 5.8 Reconstructed requests lose their headers
- **Location:** `Sources/Convey/Utility/CodableURLRequest.swift:31-55,160-203`
- **What:** The type records `allHTTPHeaderFields` and `allowsPersistentDNS`, but `request(withData:)` restores neither.
- **Why:** A public record/rebuild round trip loses authorization, content negotiation, routing, and DNS behavior.
- **Action:** Restore every captured property under matching availability guards and define how redacted credentials must be refreshed.
- **Severity:** High

### 5.9 Image sizing uses inverted and unreachable comparisons
- **Status (2026-07-20): Addressed.** Fit/fill geometry and max/exact comparisons were re-derived and covered for portrait, landscape, and asymmetric bounds; resizing now draws scaled content on iOS and macOS.
- **Location:** `Sources/Convey/Caching/ImageSizing.swift:26-42,122-136`
- **What:** Fit/fill repeats the same aspect-ratio condition, max-size matching rejects smaller images while accepting oversized ones, and the height check compares against width.
- **Why:** Images can remain oversized, be unnecessarily upscaled, or receive incorrect dimensions.
- **Action:** Re-derive fit/fill and max/exact semantics and cover portrait, landscape, square, and asymmetric constraints with tests.
- **Severity:** High

### 5.10 Upload gzip defaults to the download switch
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Uploading.swift:16-26`; `Sources/Convey/Tasks/DownloadingTask+Request.swift:11-17`
- **What:** `UploadingTask.gzip` reads `enableGZipDownloads` even though request compression is gated by `enableGZipUploads`.
- **Why:** Enabling uploads while disabling downloads unexpectedly prevents default upload compression.
- **Action:** Derive upload behavior solely from upload configuration and test all server/task override combinations.
- **Severity:** High

### 5.11 macOS image MIME parts never contain image data
- **Location:** `Sources/Convey/Utility/PlatformImage.swift:8-19`; `Sources/Convey/Tasks/MIMEUploadingTask.swift:127-130`
- **What:** The macOS `NSImage.jpegData` implementation always returns `nil`, while MIME image components rely on it.
- **Why:** The package builds on macOS but silently uploads an empty image part.
- **Action:** Implement bitmap representation/JPEG encoding for `NSImage` and make encoding failure explicit.
- **Severity:** High

### 5.12 `send()` silently succeeds when no server is configured
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Download.swift:44-48`
- **What:** `send()` returns without performing work when `server.isSetup` is false, unlike `download()`.
- **Why:** Callers cannot distinguish a sent request from a configuration failure despite the method being throwing.
- **Action:** Let session creation throw `serverNotConfigured` consistently.
- **Severity:** Medium

### 5.13 The fluent query-parameter modifier is a no-op by default
- **Location:** `Sources/Convey/Tasks/ConfigurableTask.swift:68-72`; `Sources/Convey/Tasks/DownloadingTask.swift:74`; `Sources/Convey/Server/ConveyServable.swift:60-77`
- **What:** The modifier writes `configuration.queryParameters`, but the default task property always returns `nil` and never reads it.
- **Why:** Calling `.queryParameters(...)` commonly produces an unchanged URL.
- **Action:** Make the default task property consult task configuration and test dictionary and `URLQueryItem` forms.
- **Severity:** Medium

### 5.14 Form uploads default to invalid form encoding
- **Location:** `Sources/Convey/Tasks/FormUploadingTask.swift:15-19,25-41`
- **What:** Percent encoding is disabled by default and the unencoded path emits a trailing ampersand.
- **Why:** Spaces, ampersands, equals signs, Unicode, and plus signs change server-side values.
- **Action:** Encode according to form rules by default and join fields without a trailing separator.
- **Severity:** Medium

### 5.15 Multipart form-data uses inconsistent separators
- **Location:** `Sources/Convey/Tasks/MIMEUploadingTask.swift:55-79,100-113`
- **What:** `.formData` adds extra CRLF sequences beyond the normal header/body separator.
- **Why:** Strict multipart parsers can reject the part or interpret blank lines as payload bytes.
- **Action:** Centralize framing so every part has one header/body blank line and one trailing CRLF.
- **Severity:** Medium

### 5.16 Image aspect-fill draws at the original size
- **Location:** `Sources/Convey/Caching/ImageSizing.swift:141-154`
- **What:** The non-fit branch creates a target canvas but draws using `image.size` instead of a scaled aspect-fill rectangle.
- **Why:** Results are cropped or padded rather than resized to the requested geometry.
- **Action:** Compute an aspect-fill scale and draw a scaled, centered rectangle.
- **Severity:** Medium

### 5.17 Timeout precedence can lengthen a task override
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Request.swift:20-25`; `Sources/Convey/Utility/ConveySession.swift:57-61`
- **What:** `computedTimeout` takes the maximum of server, task, request, and resource values and applies that maximum to the request.
- **Why:** A task requesting a shorter timeout can still wait for the longer server default.
- **Action:** Define override precedence and keep request and resource timeouts separate.
- **Severity:** Medium

## 6. Security

### 6.1 Recorded-task redaction does not cover URLs or bodies
- **Status (2026-07-20): Addressed.** Query strings, request bodies, response bodies, and detailed error descriptions are metadata-only by default with explicit server opt-ins; serialized request URLs are sanitized too. Recoverable task state remains an explicit `StorableTask` opt-in.
- **Location:** `Sources/Convey/TaskRecording/TaskRecordingInfo.swift:38-55,68-82`; `Sources/Convey/TaskRecording/TaskRecordingInfo+Chronicle.swift:27-35`; `Sources/Convey/TaskRecording/RecordedTask.swift:18-21,84-105`
- **What:** Header values can be redacted, but full URLs/query values, request and response bodies, errors, and encoded `StorableTask` state are passed to Chronicle or SwiftData.
- **Why:** Tokens, credentials, PII, and application data commonly live outside headers and can persist beyond the network request.
- **Action:** Make body/query/task-state capture opt-in, add field-level redaction hooks and hard size limits, and document retention and storage protection.
- **Severity:** High

### 6.2 MIME header parameters accept unsanitized metadata
- **Location:** `Sources/Convey/Tasks/MIMEUploadingTask.swift:116-138,150-170`
- **What:** Filenames, content types, and boundaries are interpolated into MIME headers while file and JSON failures are swallowed with `try?`.
- **Why:** Quotes or control characters can corrupt framing, and missing content can be submitted without an error.
- **Action:** Make construction throwing and validate or encode all header parameters and boundaries.
- **Severity:** Medium

### 6.3 Recorded-task exports remain in predictable temporary files
- **Location:** `Sources/Convey/UI/RecordedTaskDetailScreen.swift:15-18,84-92`
- **What:** Full task JSON is written under a predictable filename and never removed.
- **Why:** Sensitive request data persists after sharing, and concurrent screens with the same suggested name can overwrite one another.
- **Action:** Use a unique per-export directory, appropriate file protection, and explicit cleanup.
- **Severity:** Medium

### 6.4 Public decompression has no output limit
- **Location:** `Sources/Convey/Utility/Data.swift:240-299`
- **What:** `gunzipped` expands until zlib reports completion with no maximum output size or expansion ratio.
- **Why:** Untrusted high-ratio input can exhaust process memory.
- **Action:** Add a configurable output cap and abort inflation once exceeded.
- **Severity:** Medium

## 7. Performance

### 7.1 Required-interface HTTP buffers an unbounded response
- **Location:** `Sources/Convey/Utility/NetworkInterfaceHTTPClient.swift:41,113-125,183-211`
- **What:** All bytes are appended until peer closure before headers or body framing are processed.
- **Why:** Large or malicious responses can exhaust memory, and repeated `Data` growth adds copying overhead.
- **Action:** Parse headers incrementally, enforce configurable limits, and stream framed body data.
- **Severity:** High

### 7.2 SSE delivery uses an unbounded event buffer
- **Location:** `Sources/Convey/Streaming/DownloadingTask+Stream.swift:78-93`
- **What:** `AsyncThrowingStream.makeStream()` uses its unbounded default while an independent reader yields events.
- **Why:** A slow or paused consumer can accumulate an indefinite stream in memory.
- **Action:** Choose a documented bounded buffering policy or expose a backpressured async sequence.
- **Severity:** Medium

### 7.3 SSE lines and events have no size limit
- **Location:** `Sources/Convey/Streaming/SSEParser.swift:12-18,34-37,72-90`; `Sources/Convey/Streaming/DownloadingTask+Stream.swift:88-94`
- **What:** Recorded bytes are capped, but an unterminated line or accumulated event data can grow without bound and is processed one byte at a time.
- **Why:** A server can drive memory growth without dispatching an event, and byte-wise actor processing is expensive.
- **Action:** Enforce line/event limits and parse buffered chunks where practical.
- **Severity:** Medium

### 7.4 MIME construction synchronously duplicates whole files
- **Location:** `Sources/Convey/Tasks/MIMEUploadingTask.swift:55-80,127-138`
- **What:** File parts use synchronous `Data(contentsOf:)` and then append into a second complete multipart `Data` value under `@ConveyActor`.
- **Why:** Large uploads block all Convey actor work and temporarily require multiple full-size buffers.
- **Action:** Stream file parts or load them outside the global actor with explicit errors.
- **Severity:** Medium

### 7.5 Unused attributed rendering performs avoidable work
- **Location:** `Sources/Convey/UI/RecordedTaskDetailScreen.swift:15-26,84-86`; `Sources/Convey/TaskRecording/RecordedTask+JSON.swift:10-48`
- **What:** `setupDisplay()` builds `attributedJSON`, but only the plain string is displayed.
- **Why:** Each refresh performs formatting and allocation with no visible effect.
- **Action:** Remove the attributed path or finish and display it.
- **Severity:** Low

## 8. SwiftUI / UI

### 8.1 `CachedURLImage` launches work from rendering and races URL changes
- **Status (2026-07-20): Addressed.** Rendering is side-effect free; one `.task(id:)` load is cancelled on URL changes, checks cancellation before assignment, applies resizing, and uses `showURLs`.
- **Location:** `Sources/Convey/UI/CachedURLImage.swift:51-91`
- **What:** Reading a computed property starts an unstructured task whenever the cache state is empty; URL changes neither cancel old work nor validate the result identity. `fetchedURL`, `showURLs`, and `imageSize` are unused.
- **Why:** Body recomputation can launch duplicate downloads, an older request can overwrite a newer image, and requested resizing is ignored.
- **Action:** Drive one cancellable `.task(id:)`, validate identity before state assignment, and implement or remove the unused options.
- **Severity:** High

### 8.2 Task rows do not scale well or describe status accessibly
- **Location:** `Sources/Convey/UI/TaskRow.swift:20-83,93-126`
- **What:** Important text uses fixed 10–13 point fonts, and cancellation/error state is conveyed mainly by emoji and color.
- **Why:** Dynamic Type users can receive undersized content, while VoiceOver users lack clear semantic status descriptions.
- **Action:** Use semantic text styles and add combined accessibility labels/values for method, status, retry, and byte counts.
- **Severity:** Medium

### 8.3 Detail controls have ambiguous interaction semantics
- **Location:** `Sources/Convey/UI/RecordedTaskDetailScreen.swift:21-26,35-67`
- **What:** A constant-bound `TextEditor` appears editable but discards edits, and the icon-only upload toggle does not state whether it shows the upload or response.
- **Why:** Users can attempt edits that vanish, and assistive technology receives an unclear action.
- **Action:** Use a read-only selectable presentation and give the toggle a state-dependent textual accessibility label.
- **Severity:** Medium

### 8.4 Recorder setup failures render an unexplained empty screen
- **Location:** `Sources/Convey/UI/RecordedTasksScreen.swift:19-32`; `Sources/Convey/TaskRecording/TaskRecorder.swift:58-65`
- **What:** Model-container creation uses `try?`, and the screen renders an empty `VStack` when no container exists.
- **Why:** Storage failures look like a blank UI with no recovery or diagnosis.
- **Action:** Preserve the setup error and render a clear unavailable/error state.
- **Severity:** Low

## 9. Dead code / duplication / refactor

### 9.1 The test-harness project has a broken local package reference
- **Status (2026-07-20): Addressed.** The reference now points to `..`; package resolution, project listing, and a generic macOS Debug build all succeed.
- **Location:** `Test Harness/ConveyTestHarness.xcodeproj/project.pbxproj:614-618`
- **What:** The local package path is `../Convey`, which resolves to a nonexistent `Convey/Convey` directory from the project location.
- **Why:** `xcodebuild -project "Test Harness/ConveyTestHarness.xcodeproj" -list` fails before schemes or builds can be resolved.
- **Action:** Point the reference at the repository root and verify the shared scheme from a clean checkout.
- **Severity:** High

### 9.2 The test suite depends heavily on live network state
- **Location:** `Tests/ConveyTests/ConveyTests.swift:12-48`; `Tests/ConveyTests/ErrorHandlingTests.swift:45-145`; `Tests/ConveyTests/ConcurrentExecutionTests.swift:41-152,206-227`
- **What:** Many tests call `httpbin.org`; the basic suite also uses an unconfigured global default server, and cancellation expectations depend on remote timing.
- **Why:** The audited run discovered 92 tests but failed after 64.6 seconds with 15 issues; outcomes varied from earlier runs as the external service changed.
- **Action:** Replace live requests with `URLProtocol`/local transport stubs, explicitly configure each server, and reserve a separately labeled integration suite for external endpoints.
- **Severity:** Medium

### 9.3 ETag and file-caching remnants are disconnected
- **Location:** `Sources/Convey/Caching/ETagStore.swift:10-48`; `Sources/Convey/Extensions/URL.swift:12-28`; `Sources/Convey/Extensions/FileManager.swift:10-15`
- **What:** `ETagStore` and its related helpers have no production or test references.
- **Why:** Dead persistence code implies ETag validation that Convey does not currently perform.
- **Action:** Remove the remnants or reconnect them explicitly to request/response handling with tests.
- **Severity:** Medium

### 9.4 Retry-state properties are incomplete or unused
- **Location:** `Sources/Convey/TaskRecording/RecordedTask.swift:38-40,53-75`; `Sources/Convey/TaskRecording/TaskRecovery+Retry.swift:41-49`
- **What:** `lastRetriedAt` and `retrySuccessfulAt` are never assigned; several storable-task helpers and date projections are unused.
- **Why:** Persisted schema and UI imply retry metadata that is never available, complicating schema evolution.
- **Action:** Define and populate one retry-state model or remove the abandoned properties through an intentional migration.
- **Severity:** Medium

### 9.5 Task presentation formatting is duplicated
- **Location:** `Sources/Convey/UI/RecordedTaskDetailScreen.swift:95-132`; `Sources/Convey/TaskRecording/RecordedTask+JSON.swift:12-43`; `Sources/Convey/Utility/CodableURLRequest.swift:78-137`
- **What:** Request, response, body, error, and separator formatting are assembled independently as strings and attributed strings.
- **Why:** The variants have already drifted and privacy/format fixes must be repeated.
- **Action:** Build one presentation-neutral section model and render it to plain or attributed text.
- **Severity:** Medium

### 9.6 A transport DTO imports SwiftUI presentation concerns
- **Location:** `Sources/Convey/Utility/CodableURLRequest.swift:8-10,77-137`
- **What:** `CodableURLRequest` owns fonts, colors, bullets, and attributed formatting.
- **Why:** Networking/persistence code gains an unnecessary SwiftUI compile dependency and mixed responsibilities.
- **Action:** Move rendering into a UI-specific extension and keep the DTO Foundation-only.
- **Severity:** Medium

### 9.7 Buffered and streaming paths duplicate lifecycle orchestration
- **Location:** `Sources/Convey/Tasks/DownloadingTask+Download.swift:97-176`; `Sources/Convey/Streaming/DownloadingTask+Stream.swift:12-120`
- **What:** Both paths independently implement session setup, hooks, recording, echo policy, error classification, cleanup, and server callbacks.
- **Why:** Behavioral drift already exists in observer callbacks, constrained-interface support, ungzipped recording, and cleanup.
- **Action:** Extract one request lifecycle with buffered and streaming strategies.
- **Severity:** Medium

### 9.8 `FileWatcher` is public but cannot be used externally
- **Location:** `Sources/Convey/Caching/FileWatcher.swift:10-37`
- **What:** The struct is public, but its initializer and `finish()` are internal; Convey never references it.
- **Why:** It exposes an unusable type and dormant file-descriptor lifecycle.
- **Action:** Delete it if obsolete or make construction/cancellation public with tests.
- **Severity:** Low

### 9.9 Recorded-tasks UI holds unused observed state
- **Location:** `Sources/Convey/UI/RecordedTasksScreen.swift:15-16,39-45,71-95`
- **What:** Launch date, counter, model context, query, toolbar placement, and a commented toolbar do not drive rendered output.
- **Why:** Unused state/query dependencies obscure data flow and can trigger needless observation/fetch work.
- **Action:** Remove unused state or restore the intended feature as active tested code.
- **Severity:** Low

### 9.10 Obsolete notifications and parsers remain
- **Location:** `Sources/Convey/Utility/Notifications.swift:11-14`; `Sources/Convey/Utility/CommandLine.swift:28-38`
- **What:** Sign-in/out notifications have no producers or consumers; unused numeric parsers remain, and `int(for:)` flips negative values positive.
- **Why:** Stale API suggests unsupported behavior and leaves a latent parsing defect.
- **Action:** Remove or deprecate unused API; correct and test parsers only if retained.
- **Severity:** Low

### 9.11 Large utility files have unclear ownership
- **Location:** `Sources/Convey/Utility/Data.swift:1-309`; `Sources/Convey/Utility/NetworkInterfaceHTTPClient.swift:1-234`
- **What:** `Data.swift` is exclusively gzip code, while the raw HTTP file combines connection lifecycle, serialization, parsing, and chunk decoding.
- **Why:** Generic/multi-responsibility files slow navigation and increase change conflicts.
- **Action:** Rename the gzip extension and split raw HTTP transport from its independently testable codec components.
- **Severity:** Low

## 10. Cross-cutting recommendations

1. **Establish one request lifecycle.** Build and customize the final request, create an owned transport operation, record start/completion exactly once, decode, then notify task/server/observers from one centralized state machine. This addresses §3.1, §3.2, §5.3, §5.4, §5.6, and §9.7 together.
2. **Define configuration precedence as an API contract.** Server defaults, server headers, task configuration, and task properties should merge once with case-insensitive header semantics and tests for every public field. This addresses §4.2–§4.5, §5.7, §5.10, §5.13, and §5.17.
3. **Make recording privacy explicit.** Treat request/response bodies, URLs, task snapshots, and exports as sensitive. Default to minimal metadata, require opt-in for content, and apply unified redaction/retention/size policy across Chronicle, SwiftData, console, and sharing.
4. **Prefer deterministic transport tests.** Use existing `URLProtocol`-style stubs for all unit tests and isolate live-server tests behind an explicit integration flag. Add targeted regression tests for every Critical/High finding before refactoring.
5. **Separate actor coordination from CPU and I/O work.** Compression, decoding, image processing, file loading, and multipart assembly should operate on immutable snapshots outside `@ConveyActor`, returning results for short actor-isolated state transitions.
6. **Add property-focused image tests.** Test size matching and fit/fill across portrait/landscape/square inputs, exact/max/tolerance cases, image URL replacement, and stale fetch cancellation.

## 11. What was NOT audited

- Third-party package internals: JohnnyCache, Chronicle, TagAlong, Suite, CrossPlatformKit, CloudSeeding, and SwiftSyntax.
- Deep algorithmic validation of the vendored zlib implementation; only its public safety and allocation behavior were reviewed.
- Instruments profiling, network packet captures, energy diagnostics, and memory graphs. Performance findings are source-level risks, not measured profiles.
- App Store signing, provisioning, CI secrets, and Xcode build-setting correctness beyond the failing local package reference and visible deployment targets.
- Localization wording and completeness.
- Deep test-coverage measurement; tests were compiled/run and obvious design gaps were reviewed, but line/branch coverage was not collected.
- Real service interoperability for every HTTP server, proxy, TLS policy, multipart parser, or SSE producer.

## 12. Verification

Initial verification: the clean package build completed successfully with one `CachedURLImage` deprecation warning. The 92-test run finished with 15 issues after 64.6 seconds, concentrated in live-network and unconfigured-server tests. The test-harness project initially failed dependency resolution.

Remediation verification (2026-07-20): all nine deterministic `AuditRegressionTests` covering the top ten findings pass. Existing header composition and redaction tests pass; live httpbin lifecycle/error tests remain externally variable as described in §9.2. `xcodebuild -project "Test Harness/ConveyTestHarness.xcodeproj" -list` resolves the local package, and the `ConveyTestHarness` generic macOS Debug build succeeds. The `CachedURLImage` deprecation warning is removed.

Critical and High findings were manually checked against these exact lines:

- **§5.1** — `Sources/Convey/TaskRecording/ModelContext.swift:50-57`: the closed range includes `all.count - count`, proving the extra deletion and `.count(0)` out-of-bounds index.
- **§3.1** — `Sources/Convey/Utility/ConveySession.swift:63-80`: line 64 shares the session; line 79 invalidates and cancels it.
- **§3.2** — `Sources/Convey/Utility/NetworkInterfaceHTTPClient.swift:24-31,78-92`: the continuation starts an `NWConnection`; no cancellation handler exists before timeout scheduling.
- **§3.3** — `Sources/Convey/TaskRecording/TaskRecorder.swift:35-39` and `Sources/Convey/TaskRecording/StorableTask.swift:40-42`: independent tasks launch retry sweeps; `TaskRecovery.swift:22-25` awaits callbacks without an in-flight claim.
- **§4.2** — `Sources/Convey/Utility/ConveySession.swift:53-61`: only task optional policies and timeouts are copied; the three server connectivity values are absent.
- **§5.2** — `Sources/Convey/Errors/HTTPError.swift:33-42`: the 400 and 500 branches return optional specialized initializers directly, bypassing the fallback.
- **§5.3** — `Sources/Convey/Tasks/DownloadingTask+Download.swift:72-83,141-150`: decoding occurs after persistence and `server.didFinish(...error:nil)`.
- **§5.4** — `Sources/Convey/Tasks/DownloadingTask+Download.swift:79-82,170-172`: both catch layers call the same observer failure method.
- **§5.5** — `Sources/Convey/UI/View+TaskObserving.swift:18,34` and `Sources/Convey/TaskRecording/TaskObserver.swift:74-93`: all instances register from fixed internal call sites that the registry treats as replacement keys.
- **§5.6** — `Sources/Convey/Tasks/DownloadingTask.swift:38-41` and `Sources/Convey/Utility/ConveySession.swift:42-47`: the hook returns no request and runs after immutable request capture.
- **§5.7** — `Sources/Convey/Tasks/DownloadingTask+Request.swift:35-42`: header arrays are concatenated and every value is passed to `addValue`.
- **§5.8** — `Sources/Convey/Utility/CodableURLRequest.swift:31-55,194-203`: headers and persistent-DNS are captured but not assigned during reconstruction.
- **§5.9** — `Sources/Convey/Caching/ImageSizing.swift:35-40,127-135`: the aspect branch is duplicated, max comparisons are inverted, and height is compared to width.
- **§5.10** — `Sources/Convey/Tasks/DownloadingTask+Uploading.swift:17` and `Sources/Convey/Tasks/DownloadingTask+Request.swift:14`: upload defaults read the download flag before upload gating.
- **§5.11** — `Sources/Convey/Utility/PlatformImage.swift:14-19` and `Sources/Convey/Tasks/MIMEUploadingTask.swift:127-130`: macOS JPEG encoding always returns `nil`, which is used as the image part body.
- **§6.1** — `Sources/Convey/TaskRecording/TaskRecordingInfo+Chronicle.swift:27-35` and `Sources/Convey/TaskRecording/RecordedTask.swift:84-105`: unredacted URL/body/task data is forwarded to persistent logging/storage.
- **§7.1** — `Sources/Convey/Utility/NetworkInterfaceHTTPClient.swift:113-125`: every chunk is appended to one `Data` until completion with no limit.
- **§8.1** — `Sources/Convey/UI/CachedURLImage.swift:51-79`: a computed property creates the task and assigns the result without URL identity or cancellation checks.
- **§9.1** — `Test Harness/ConveyTestHarness.xcodeproj/project.pbxproj:614-618`: the `../Convey` relative path reproduces the nonexistent nested package location reported by `xcodebuild`.

If a cited finding does not reproduce when opened at its listed lines, re-run the audit against the current revision before acting; line numbers and behavior can shift after fixes.
