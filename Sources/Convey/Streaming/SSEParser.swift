//
//  SSEParser.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/10/26.
//

import Foundation

// Incremental parser for text/event-stream per the WHATWG SSE spec:
// lines end in LF, CR, or CRLF; a blank line dispatches the buffered event.
struct SSEParser {
	private var lineBuffer: [UInt8] = []
	private var dataLines: [String] = []
	private var eventType: String?
	private var lastEventID: String?
	private var retry: Int?
	private var precededByCR = false
	private var isFirstLine = true

	mutating func consume(byte: UInt8) -> ServerSentEvent? {
		switch byte {
		case 0x0A:
			if precededByCR {
				precededByCR = false
				return nil
			}
			return finishLine()

		case 0x0D:
			precededByCR = true
			return finishLine()

		default:
			precededByCR = false
			lineBuffer.append(byte)
			return nil
		}
	}

	mutating func consume<Bytes: Sequence<UInt8>>(bytes: Bytes) -> [ServerSentEvent] {
		bytes.compactMap { consume(byte: $0) }
	}

	private mutating func finishLine() -> ServerSentEvent? {
		var line = String(decoding: lineBuffer, as: UTF8.self)
		lineBuffer = []

		if isFirstLine {
			isFirstLine = false
			if line.hasPrefix("\u{FEFF}") { line.removeFirst() }
		}
		return consume(line: line)
	}

	mutating func consume(line: String) -> ServerSentEvent? {
		if line.isEmpty { return dispatchEvent() }
		if line.hasPrefix(":") { return nil }

		let name: Substring
		var value: Substring

		if let colon = line.firstIndex(of: ":") {
			name = line[..<colon]
			value = line[line.index(after: colon)...]
			if value.hasPrefix(" ") { value.removeFirst() }
		} else {
			name = line[...]
			value = ""
		}

		switch name {
		case "data": dataLines.append(String(value))
		case "event": eventType = String(value)
		case "id": if !value.contains("\0") { lastEventID = String(value) }
		case "retry": if let milliseconds = Int(value) { retry = milliseconds }
		default: break
		}
		return nil
	}

	private mutating func dispatchEvent() -> ServerSentEvent? {
		let type = eventType
		eventType = nil

		if dataLines.isEmpty { return nil }
		let data = dataLines.joined(separator: "\n")
		dataLines = []

		return ServerSentEvent(id: lastEventID, event: type, data: data, retry: retry)
	}
}
