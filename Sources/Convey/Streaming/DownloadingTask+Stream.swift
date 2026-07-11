//
//  DownloadingTask+Stream.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/10/26.
//

import Foundation

@available(iOS 15, macOS 12, watchOS 8, *)
public extension DownloadingTask {
	func stream(file: String = #file, function: String = #function, line: Int = #line) async throws -> ServerEventStream {
		var info = TaskRecordingInfo(self, id: nil)
		let session: ConveySession

		if CommandLine.failAllRequests {
			throw FaillAllRequestsError(target: String(describing: type(of: self)))
		}

		do {
			session = try await server.session(for: self)
			session.start()
		} catch {
			info.wasCancelled = error.isCancellation
			info.error = error.localizedDescription
			info.url = await self.url
			await didFail(with: error)
			if server.configuration.logCancelledTasks || !info.wasCancelled {
				echo(info, data: nil)
				await info.save(file: file, function: function, line: line)
			}
			throw error
		}

		do {
			info.urlRequest = session.request
			info.url = session.request.url
			info.timeoutDuration = session.request.timeoutInterval

			try await willSendRequest(request: session.request)
			let (bytes, response) = try await session.openByteStream()
			info.urlResponse = response

			guard let httpResponse = response as? HTTPURLResponse else {
				throw URLError(.badServerResponse)
			}

			let statusFamily = (httpResponse.statusCode / 100) * 100
			if throwingStatusCategories.contains(statusFamily) {
				let body = try? await bytes.collect(upTo: 100_000)
				info.data = body
				if let error = HTTPError.withStatusCode(httpResponse.statusCode, data: body, throwingStatusCategories: throwingStatusCategories, underlyingError: nil) {
					throw error
				}
			}

			let events = eventStream(reading: bytes, session: session, info: info, file: file, function: function, line: line)
			return ServerEventStream(request: session.request, response: httpResponse, events: events)
		} catch {
			session.finish()
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.error = error.prettyDescription
			info.wasCancelled = error.isCancellation
			info.timedOut = error.isTimeOut
			await didFail(with: error)
			if server.configuration.logCancelledTasks || !info.wasCancelled {
				echo(info, data: nil)
				await info.save(file: file, function: function, line: line)
			}
			await server.didFinish(task: self, response: nil, error: error)
			throw error
		}
	}
}

@available(iOS 15, macOS 12, watchOS 8, *)
extension DownloadingTask {
	private func eventStream(reading bytes: URLSession.AsyncBytes, session: ConveySession, info: TaskRecordingInfo, file: String, function: String, line: Int) -> AsyncThrowingStream<ServerSentEvent, Error> {
		let maxRecordedBytes = server.configuration.maxLoggedDownloadSize

		let (stream, continuation) = AsyncThrowingStream<ServerSentEvent, Error>.makeStream()
		let reader = Task { @ConveyActor in
			var info = info
			var parser = SSEParser()
			var recorded = Data()
			var streamError: (any Error)?

			do {
				for try await byte in bytes {
					if recorded.count < maxRecordedBytes { recorded.append(byte) }
					if let event = parser.consume(byte: byte) {
						continuation.yield(event)
					}
				}
				info.isComplete = true
			} catch {
				streamError = error
				info.error = error.prettyDescription
				info.wasCancelled = error.isCancellation
				info.timedOut = error.isTimeOut
				await didFail(with: error)
			}

			session.finish()
			info.data = recorded
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.echoStyle = echoStyle(for: info.data)
			if server.configuration.logCancelledTasks || !info.wasCancelled {
				echo(info, data: info.data)
				await info.save(file: file, function: function, line: line)
			}
			await server.didFinish(task: self, response: nil, error: streamError)
			continuation.finish(throwing: streamError)
		}

		continuation.onTermination = { termination in
			if case .cancelled = termination { reader.cancel() }
		}
		return stream
	}
}

@available(iOS 15, macOS 12, watchOS 8, *)
private extension URLSession.AsyncBytes {
	func collect(upTo limit: Int) async throws -> Data {
		var data = Data()
		for try await byte in self {
			data.append(byte)
			if data.count >= limit { break }
		}
		return data
	}
}
