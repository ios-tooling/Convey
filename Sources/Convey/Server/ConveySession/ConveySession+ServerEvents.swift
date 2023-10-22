//
//  ConveySession+ServerEvents.swift
//
//
//  Created by Ben Gottlieb on 10/16/23.
//

import Foundation

public struct ServerEvent {
	public var event: String?
	public var data: String?
	public var retry: Int?
	public var id: String?
	public var comment: String?
	
	var isEmpty: Bool { event == nil && data == nil && retry == nil && id == nil && comment == nil }
	var isDone: Bool {
		data == "[DONE]"
	}
}

fileprivate enum EventPart: String, CaseIterable { case event, data, retry, id, comment
	static var standardParts: [EventPart] = [.event, .data, .retry, .id]
}

extension ConveySession: URLSessionDataDelegate {
	func start(request: URLRequest) throws -> AsyncStream<ServerEvent> {
		receivedData = Data()
		let task = session.dataTask(with: request)
		task.resume()
		
		let sequence = AsyncStream(ServerEvent.self) { constructor in
			self.streamContinuation = constructor
		}
		
		return sequence
	}
	
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		self.receivedData?.append(data)
		queue?.addOperation {
			self.checkForServerEvents()
		}
	}
	
	func checkForServerEvents() {
		guard let separator = "\n\n".data(using: .utf8), var received = receivedData else { return }
		while let range = received.firstRange(of: separator) {
			let chunk = received[0..<range.lowerBound]
			received = Data(received.dropFirst(range.upperBound))
			if let string = String(data: chunk, encoding: .utf8) {
				var newEvent = ServerEvent()
				
				let lines = string.components(separatedBy: .newlines)
				for line in lines {
					if let (key, value) = line.parseEventData() {
						switch key {
						case .data: newEvent.data = (newEvent.data ?? "") + value
						case .event: newEvent.event = value
						case .id: newEvent.id = value
						case .retry: newEvent.retry = Int(value)
						case .comment: newEvent.comment = value
						}
					}
				}
				
				if newEvent.isDone {
					streamContinuation?.finish()
				} else if !newEvent.isEmpty {
					streamContinuation?.yield(newEvent)
				}
			}
		}
		receivedData = received
	}
}

fileprivate extension String {
	func parseEventData() -> (EventPart, String)? {
		if hasPrefix(":") { return (.comment, String(dropFirst())) } 			// comment
		
		for part in EventPart.allCases {
			if hasPrefix(part.rawValue + ":") {
				return (part, String(self.dropFirst(part.rawValue.count + 1).trimmingCharacters(in: .whitespaces)))
			}
		}
		return nil
	}
}
