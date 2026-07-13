import Foundation
import Network
import Security

public enum NetworkInterfaceHTTPError: Error, LocalizedError, Sendable {
	case invalidURL
	case timedOut
	case connection(String)
	case invalidResponse

	public var errorDescription: String? {
		switch self {
		case .invalidURL: "The request URL is not valid for a network-interface request."
		case .timedOut: "The network-interface request timed out."
		case .connection(let message): "The network-interface connection failed: \(message)"
		case .invalidResponse: "The server returned an invalid HTTP response."
		}
	}
}

struct NetworkInterfaceHTTPClient: Sendable {
	let requiredInterface: ConveyNetworkInterface

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		try await withCheckedThrowingContinuation { continuation in
			NetworkInterfaceHTTPRequest(
				request: request,
				requiredInterface: requiredInterface,
				continuation: continuation
			).start()
		}
	}
}

private final class NetworkInterfaceHTTPRequest: @unchecked Sendable {
	private let request: URLRequest
	private let requiredInterface: ConveyNetworkInterface
	private let continuation: CheckedContinuation<(Data, URLResponse), any Error>
	private let queue = DispatchQueue(label: "Convey.network-interface-http-\(UUID().uuidString)")
	private var connection: NWConnection?
	private var responseData = Data()
	private var didSend = false
	private var didFinish = false

	init(
		request: URLRequest,
		requiredInterface: ConveyNetworkInterface,
		continuation: CheckedContinuation<(Data, URLResponse), any Error>
	) {
		self.request = request
		self.requiredInterface = requiredInterface
		self.continuation = continuation
	}

	func start() {
		guard let url = request.url,
			let scheme = url.scheme?.lowercased(),
			["http", "https"].contains(scheme),
			let host = url.host,
			let port = NWEndpoint.Port(rawValue: UInt16(url.port ?? (scheme == "https" ? 443 : 80)))
		else {
			finish(throwing: NetworkInterfaceHTTPError.invalidURL)
			return
		}

		let parameters: NWParameters
		if scheme == "https" {
			let tls = NWProtocolTLS.Options()
			sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, host)
			parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
		} else {
			parameters = NWParameters.tcp
		}
		parameters.requiredInterfaceType = requiredInterface.nwInterfaceType
		parameters.prohibitExpensivePaths = !request.allowsExpensiveNetworkAccess
		parameters.prohibitConstrainedPaths = !request.allowsConstrainedNetworkAccess

		let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: parameters)
		self.connection = connection
		connection.stateUpdateHandler = { state in
			switch state {
			case .ready: self.sendRequest()
			case .failed(let error): self.finish(throwing: NetworkInterfaceHTTPError.connection(error.localizedDescription))
			case .cancelled where !self.didFinish: self.finish(throwing: CancellationError())
			default: break
			}
		}
		connection.start(queue: queue)
		queue.asyncAfter(deadline: .now() + request.timeoutInterval) { [weak self] in
			guard let self, !self.didFinish else { return }
			self.finish(throwing: NetworkInterfaceHTTPError.timedOut)
		}
	}

	private func sendRequest() {
		guard !didSend, let connection else { return }
		didSend = true
		do {
			let bytes = try HTTPRequestSerializer.data(for: request)
			connection.send(content: bytes, completion: .contentProcessed { [weak self] error in
				guard let self else { return }
				if let error {
					self.finish(throwing: NetworkInterfaceHTTPError.connection(error.localizedDescription))
				} else {
					self.receiveNext()
				}
			})
		} catch {
			finish(throwing: error)
		}
	}

	private func receiveNext() {
		guard let connection, !didFinish else { return }
		connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { [weak self] content, _, isComplete, error in
			guard let self else { return }
			if let content { self.responseData.append(content) }
			if let error {
				self.finish(throwing: NetworkInterfaceHTTPError.connection(error.localizedDescription))
			} else if isComplete {
				do { self.finish(returning: try HTTPResponseParser.parse(self.responseData, requestURL: self.request.url)) }
				catch { self.finish(throwing: error) }
			} else {
				self.receiveNext()
			}
		}
	}

	private func finish(returning value: (Data, URLResponse)) {
		guard !didFinish else { return }
		didFinish = true
		connection?.stateUpdateHandler = nil
		connection?.cancel()
		continuation.resume(returning: value)
	}

	private func finish(throwing error: any Error) {
		guard !didFinish else { return }
		didFinish = true
		connection?.stateUpdateHandler = nil
		connection?.cancel()
		continuation.resume(throwing: error)
	}
}

private extension ConveyNetworkInterface {
	var nwInterfaceType: NWInterface.InterfaceType {
		switch self {
		case .cellular: .cellular
		case .wifi: .wifi
		case .wiredEthernet: .wiredEthernet
		case .loopback: .loopback
		case .other: .other
		}
	}
}

enum HTTPRequestSerializer {
	static func data(for request: URLRequest) throws -> Data {
		guard let url = request.url, let host = url.host else { throw NetworkInterfaceHTTPError.invalidURL }
		var path = url.path.isEmpty ? "/" : url.path
		if let query = url.query, !query.isEmpty { path += "?\(query)" }
		let method = request.httpMethod ?? "GET"
		var headers = request.allHTTPHeaderFields ?? [:]
		headers["Host"] = url.port.map { "\(host):\($0)" } ?? host
		headers["Accept"] = headers["Accept"] ?? "*/*"
		headers["Accept-Encoding"] = "identity"
		headers["Connection"] = "close"
		let body = request.httpBody ?? Data()
		if !body.isEmpty { headers["Content-Length"] = "\(body.count)" }

		var head = "\(method) \(path) HTTP/1.1\r\n"
		for (name, value) in headers.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
			head += "\(name): \(value)\r\n"
		}
		head += "\r\n"
		var data = Data(head.utf8)
		data.append(body)
		return data
	}
}

enum HTTPResponseParser {
	static func parse(_ data: Data, requestURL: URL?) throws -> (Data, URLResponse) {
		let separator = Data("\r\n\r\n".utf8)
		guard let headerRange = data.range(of: separator),
			let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8),
			let url = requestURL
		else { throw NetworkInterfaceHTTPError.invalidResponse }

		let lines = headerText.components(separatedBy: "\r\n")
		guard let statusLine = lines.first else { throw NetworkInterfaceHTTPError.invalidResponse }
		let statusParts = statusLine.split(separator: " ", maxSplits: 2)
		guard statusParts.count >= 2, let statusCode = Int(statusParts[1]) else {
			throw NetworkInterfaceHTTPError.invalidResponse
		}
		var headers: [String: String] = [:]
		for line in lines.dropFirst() {
			guard let colon = line.firstIndex(of: ":") else { continue }
			let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
			let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
			headers[name] = value
		}
		guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers) else {
			throw NetworkInterfaceHTTPError.invalidResponse
		}
		let body = Data(data[headerRange.upperBound...])
		if headers.first(where: { $0.key.caseInsensitiveCompare("Transfer-Encoding") == .orderedSame })?.value.lowercased().contains("chunked") == true {
			return (try decodeChunked(body), response)
		}
		return (body, response)
	}

	private static func decodeChunked(_ data: Data) throws -> Data {
		var cursor = data.startIndex
		var result = Data()
		let lineEnd = Data("\r\n".utf8)
		while cursor < data.endIndex {
			guard let sizeRange = data[cursor...].range(of: lineEnd),
				let sizeLine = String(data: data[cursor..<sizeRange.lowerBound], encoding: .utf8),
				let size = Int(sizeLine.split(separator: ";", maxSplits: 1)[0], radix: 16)
			else { throw NetworkInterfaceHTTPError.invalidResponse }
			cursor = sizeRange.upperBound
			if size == 0 { return result }
			guard data.distance(from: cursor, to: data.endIndex) >= size + 2 else {
				throw NetworkInterfaceHTTPError.invalidResponse
			}
			let end = data.index(cursor, offsetBy: size)
			result.append(data[cursor..<end])
			cursor = data.index(end, offsetBy: 2)
		}
		throw NetworkInterfaceHTTPError.invalidResponse
	}
}
