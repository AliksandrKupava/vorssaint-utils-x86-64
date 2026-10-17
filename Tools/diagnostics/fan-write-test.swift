import Foundation
import IOKit
struct SMCVersion { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
struct SMCPLimitData { var version: UInt16 = 0, length: UInt16 = 0; var cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0 }
struct SMCKeyInfoData { var dataSize: UInt32 = 0, dataType: UInt32 = 0, dataAttributes: UInt8 = 0 }
struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}
var connection: io_connect_t = 0
let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
guard service != 0, IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { print("open failed"); exit(1) }
func fccU(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
func readRaw(name: String, size: UInt32) -> [UInt8] {
    var p = SMCParamStruct(); p.key = fccU(name); p.keyInfo.dataSize = size; p.data8 = 5
    var output = SMCParamStruct(); var outSize = MemoryLayout<SMCParamStruct>.stride
    _ = IOConnectCallStructMethod(connection, 2, &p, MemoryLayout<SMCParamStruct>.stride, &output, &outSize)
    return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(size))) }
}
func writeRaw(name: String, size: UInt32, bytes: [UInt8]) -> UInt8 {
    var p = SMCParamStruct(); p.key = fccU(name); p.keyInfo.dataSize = size; p.data8 = 6
    withUnsafeMutableBytes(of: &p.bytes) { $0.copyBytes(from: bytes) }
    var output = SMCParamStruct(); var outSize = MemoryLayout<SMCParamStruct>.stride
    let kr = IOConnectCallStructMethod(connection, 2, &p, MemoryLayout<SMCParamStruct>.stride, &output, &outSize)
    print("  write kr=\(kr) result=\(output.result)")
    return output.result
}
// F0Tg: fpe2 1200 rpm = 0x12c0. Попробуем 1400 rpm = 0x15e0
let target: [UInt8] = [0x15, 0xe0]
let before = readRaw(name: "F0Tg", size: 2)
print("F0Tg before: \(before.map { String(format: "%02x", $0) }.joined())")
let r = writeRaw(name: "F0Tg", size: 2, bytes: target)
let after = readRaw(name: "F0Tg", size: 2)
print("F0Tg after:  \(after.map { String(format: "%02x", $0) }.joined()) (write result=\(r))")
print(r == 0 && after == target ? "WRITE WORKS" : "WRITE REJECTED")
