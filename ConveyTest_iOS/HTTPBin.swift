//
//  HTTPBin.swift
//  ConveyTest_iOS
//
//  Created by Ben Gottlieb on 5/22/22.
//

import Foundation

class HTTPBinServer: Server {
	static let instance = HTTPBinServer()
	
	init() {
		super.init(asDefault: true)
		self.remote = Remote(URL("https://httpbin.org/"), name: "HTTPBin", shortName: "HTTPBin")
	}
}

struct SampleHTTPBinPOST: ServerTask, ServerPOSTTask, DataUploadingTask, ThreadedServerTask, PostFlightTask {
	var path: String = "post"
	var dataToUpload: Data?
	var server: Server { HTTPBinServer.instance }
	var threadName: String? = "httpBinPost"
	
	init(index: Int) {
		dataToUpload = "\(index)".data(using: .utf8)
	}
	
	func postprocess(response: ServerReturned) {
		do {
			if let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any], let index = json["data"] as? String {
				print("\(index): HTTPBin Post")
			}
		} catch {
			print("Failed to decode json")
		}
	}
	
	func postFlight() async throws {
		try await Task.sleep(nanoseconds: 1_000_000_000)
	}
}
