//
//  HTTPBin.swift
//  ConveyTestHarness
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation

class HTTPBinServer: ConveyServer {
	static let instance = HTTPBinServer()
	
	init() {
		super.init(asDefault: true)
		self.remote = Remote(URL("https://httpbin.org/"), name: "HTTPBin", shortName: "HTTPBin")
	}
}

struct SampleHTTPBinPOST: ServerTask, ServerPOSTTask, DataUploadingTask, ThreadedServerTask {
	var contentType: String?
	
	var path: String = "post"
	var dataToUpload: Data?
	var server: ConveyServer { HTTPBinServer.instance }
	var threadName: String? = "httpBinPost"
	
	init(index: Int) {
		dataToUpload = "\(index)".data(using: .utf8)
	}
	
	func postProcess(response: ServerResponse) async throws {
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
