//
//  URLAuthenticationChallenge.swift
//  
//
//  Created by Ben Gottlieb on 10/22/23.
//

import Foundation
import CryptoKit

extension URLAuthenticationChallenge {
	var host: String { protectionSpace.host }
	
	var publicKey: String? {
		guard let serverTrust = self.protectionSpace.serverTrust else { return nil }
		#if os(visionOS)
			guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate], let certificate = certificates.first else { return nil }
		#else
			guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else { return nil }
		#endif
		
		let policies = [SecPolicyCreateSSL(true, host as CFString)] as NSArray
		SecTrustSetPolicies(serverTrust, policies)
		
		
		var error: CFError?
		if !SecTrustEvaluateWithError(serverTrust, &error) {
			return nil
		}

		var publicKeyError: Unmanaged<CFError>?
		if let publicKey = SecCertificateCopyKey(certificate), let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &publicKeyError) as? Data {
			let rsa2048Asn1Header: [UInt8] = [
				0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
				0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
			]
			var keyWithHeader = Data(rsa2048Asn1Header)
			keyWithHeader.append(publicKeyData)
			let digest = SHA256.hash(data: keyWithHeader)
			let digestString = Data(digest).base64EncodedString()
			return digestString
		}
		return nil
	}
}
