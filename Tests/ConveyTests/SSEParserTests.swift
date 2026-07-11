//
//  SSEParserTests.swift
//  Convey
//

import Testing
import Foundation
@testable import Convey

@Suite("SSE Parser")
struct SSEParserTests {
	private func parse(_ text: String) -> [ServerSentEvent] {
		var parser = SSEParser()
		return parser.consume(bytes: Array(text.utf8))
	}

	@Test("Single data event")
	func singleEvent() {
		let events = parse("data: hello\n\n")
		#expect(events == [ServerSentEvent(data: "hello")])
	}

	@Test("Multi-line data is joined with newlines")
	func multiLineData() {
		let events = parse("data: line one\ndata: line two\n\n")
		#expect(events.count == 1)
		#expect(events.first?.data == "line one\nline two")
	}

	@Test("Event type is captured and reset after dispatch")
	func eventType() {
		let events = parse("event: delta\ndata: a\n\ndata: b\n\n")
		#expect(events.count == 2)
		#expect(events[0].event == "delta")
		#expect(events[1].event == nil)
	}

	@Test("Last event ID persists across events")
	func idPersistence() {
		let events = parse("id: 42\ndata: a\n\ndata: b\n\n")
		#expect(events.count == 2)
		#expect(events[0].id == "42")
		#expect(events[1].id == "42")
	}

	@Test("Comment lines are ignored")
	func comments() {
		let events = parse(": keep-alive\ndata: real\n\n")
		#expect(events == [ServerSentEvent(data: "real")])
	}

	@Test("Retry field is parsed as milliseconds")
	func retry() {
		let events = parse("retry: 3000\ndata: x\n\n")
		#expect(events.first?.retry == 3000)
	}

	@Test("Non-numeric retry is ignored")
	func badRetry() {
		let events = parse("retry: soon\ndata: x\n\n")
		#expect(events.first?.retry == nil)
	}

	@Test("Blank line without data dispatches nothing")
	func noDataNoDispatch() {
		let events = parse("event: ping\n\n")
		#expect(events.isEmpty)
	}

	@Test("No dispatch without trailing blank line")
	func incompleteEvent() {
		let events = parse("data: incomplete\n")
		#expect(events.isEmpty)
	}

	@Test("Field without colon is treated as name with empty value")
	func fieldWithoutColon() {
		let events = parse("data\n\n")
		#expect(events == [ServerSentEvent(data: "")])
	}

	@Test("Value keeps only a single leading space stripped")
	func spaceHandling() {
		#expect(parse("data:tight\n\n").first?.data == "tight")
		#expect(parse("data:  padded\n\n").first?.data == " padded")
	}

	@Test("CRLF line endings")
	func crlf() {
		let events = parse("data: a\r\ndata: b\r\n\r\n")
		#expect(events.count == 1)
		#expect(events.first?.data == "a\nb")
	}

	@Test("CR-only line endings")
	func crOnly() {
		let events = parse("data: a\r\r")
		#expect(events == [ServerSentEvent(data: "a")])
	}

	@Test("Leading BOM is stripped")
	func bom() {
		let events = parse("\u{FEFF}data: hello\n\n")
		#expect(events == [ServerSentEvent(data: "hello")])
	}

	@Test("Byte-at-a-time parsing matches whole-string parsing")
	func chunkBoundaries() {
		var parser = SSEParser()
		var events: [ServerSentEvent] = []
		for byte in Array("event: delta\ndata: {\"text\": \"héllo\"}\n\n".utf8) {
			if let event = parser.consume(byte: byte) { events.append(event) }
		}
		#expect(events.count == 1)
		#expect(events.first?.data == "{\"text\": \"héllo\"}")
	}

	@Test("Typical LLM stream shape")
	func llmStream() {
		let events = parse("data: {\"delta\": \"Hel\"}\n\ndata: {\"delta\": \"lo\"}\n\ndata: [DONE]\n\n")
		#expect(events.count == 3)
		#expect(events.last?.data == "[DONE]")
	}
}
