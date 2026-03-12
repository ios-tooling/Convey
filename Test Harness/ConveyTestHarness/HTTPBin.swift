//
//  HTTPBin.swift
//  ConveyTestHarness
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation
import Convey


@ConveyActor class HTTPBinServer: ConveyServerable {
	var remote: Convey.Remote
	
	var configuration: ServerConfiguration = .default
	
	static let instance = HTTPBinServer()
	
	init() {
		self.remote = Remote(URL("https://httpbin.org/"), name: "HTTPBin", shortName: "HTTPBin")
	}
}

struct SampleHTTPBinPOST: DataUploadingTask {
	var configuration: Convey.TaskConfiguration?
	
	var contentType: String?
	
	var path = "post"
	var uploadPayload: Data?
	var server: ConveyServerable { HTTPBinServer.instance }
	var threadName: String? = "httpBinPost"
	
	init(index: Int) {
		uploadPayload = "\(index)".data(using: .utf8)
	}
	
//	func postProcess(response: ServerResponse) async throws {
//		do {
//			if let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any], let index = json["data"] as? String {
//				print("\(index): HTTPBin Post")
//			}
//		} catch {
//			print("Failed to decode json")
//		}
//	}
	
	func postFlight() async throws {
		try await Task.sleep(nanoseconds: 1_000_000_000)
	}
}
