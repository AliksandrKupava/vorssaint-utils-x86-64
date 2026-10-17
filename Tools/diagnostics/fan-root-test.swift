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
defer { IOServiceClose(connection) }
func fccU(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
func writeRaw(name: String, size: UInt32, bytes: [UInt8]) -> (kr: kern_return_t, result: UInt8) {
    var p = SMCParamStruct(); p.key = fccU(name); p.keyInfo.dataSize = size; p.data8 = 6
    withUnsafeMutableBytes(of: &p.bytes) { $0.copyBytes(from: bytes) }
    var output = SMCParamStruct(); var outSize = MemoryLayout<SMCParamStruct>.stride
    let kr = IOConnectCallStructMethod(connection, 2, &p, MemoryLayout<SMCParamStruct>.stride, &output, &outSize)
    return (kr, output.result)
}
func readRaw(name: String, size: UInt32) -> [UInt8] {
    var p = SMCParamStruct(); p.key = fccU(name); p.keyInfo.dataSize = size; p.data8 = 5
    var output = SMCParamStruct(); var outSize = MemoryLayout<SMCParamStruct>.stride
    _ = IOConnectCallStructMethod(connection, 2, &p, MemoryLayout<SMCParamStruct>.stride, &output, &outSize)
    return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(size))) }
}
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }

// 1. Ручной режим F0Md=1 (для i5 iMac19,2 один вентилятор, index 0)
let md = writeRaw(name: "F0Md", size: 1, bytes: [0x01])
print("1) F0Md=1: kr=\(md.kr) result=\(md.result)")

// 2. Сразу пишем target 2000 rpm = fpe2 0x1f40
let tg = writeRaw(name: "F0Tg", size: 2, bytes: [0x1f, 0x40])
print("2) F0Tg=2000rpm: kr=\(tg.kr) result=\(tg.result)")
Thread.sleep(forTimeInterval: 1)

// 3. Читаем фактические обороты и target
let act = readRaw(name: "F0Ac", size: 2)
let actRpm = (Double(act[0]) * 256 + Double(act[1])) / 4
let tgt = readRaw(name: "F0Tg", size: 2)
let tgtRpm = (Double(tgt[0]) * 256 + Double(tgt[1])) / 4
print("3) через 1с: F0Tg=\(String(format: "%.0f", tgtRpm)) rpm, F0Ac=\(String(format: "%.0f", actRpm)) rpm")

if tgtRpm > 1500 {
    print("MANUAL MODE WORKS — fan target accepted")
    print(">>> Возврат в авто-режим: пишем F0Md=0")
    _ = writeRaw(name: "F0Md", size: 1, bytes: [0x00])
    Thread.sleep(forTimeInterval: 1)
    let back = readRaw(name: "F0Tg", size: 2)
    print(">>> F0Tg после возврата: \((Double(back[0])*256+Double(back[1]))/4) rpm")
} else {
    print("TARGET STILL OVERRIDDEN — даже под root контроллер возвращает обороты")
}
