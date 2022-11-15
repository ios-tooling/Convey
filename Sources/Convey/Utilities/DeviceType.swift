//
//  DeviceType.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation

class Device {

   #if os(macOS)
      public static var rawDeviceType: String {
         let service: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
         let cfstr = "model" as CFString
         if let model = IORegistryEntryCreateCFProperty(service, cfstr, kCFAllocatorDefault, 0).takeUnretainedValue() as? Data {
           if let nsstr =  String(data: model, encoding: .utf8) {
                 return nsstr
             }
         }
         return ""
      }
   #endif
   
   #if os(iOS) || os(watchOS)
      public static var rawDeviceType: String {
         var         systemInfo = utsname()
         uname(&systemInfo)
         let machineMirror = Mirror(reflecting: systemInfo.machine)
         let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8 , value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
         }
         return identifier
      }
   #endif
}
