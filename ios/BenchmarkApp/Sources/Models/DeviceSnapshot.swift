import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct DeviceSnapshot: Codable, Sendable {
    public let modelIdentifier: String
    public let systemName: String
    public let systemVersion: String
    public let processorCount: Int
    public let physicalMemoryMB: Int
    public let isLowPowerModeEnabled: Bool
    public let batteryState: String
    public let batteryLevel: Float
    public let initialThermalState: String
    public let buildConfiguration: String

    public static func capture() -> DeviceSnapshot {
        let info = ProcessInfo.processInfo
        let physicalMemory = Int(info.physicalMemory / (1024 * 1024))

        var batteryState = "unknown"
        var batteryLevel: Float = -1
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        switch UIDevice.current.batteryState {
        case .charging: batteryState = "charging"
        case .full: batteryState = "full"
        case .unplugged: batteryState = "unplugged"
        case .unknown: batteryState = "unknown"
        @unknown default: batteryState = "unknown"
        }
        batteryLevel = UIDevice.current.batteryLevel
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        #else
        let systemName = "macOS"
        let systemVersion = info.operatingSystemVersionString
        #endif

        return DeviceSnapshot(
            modelIdentifier: hardwareModelIdentifier(),
            systemName: systemName,
            systemVersion: systemVersion,
            processorCount: info.processorCount,
            physicalMemoryMB: physicalMemory,
            isLowPowerModeEnabled: info.isLowPowerModeEnabled,
            batteryState: batteryState,
            batteryLevel: batteryLevel,
            initialThermalState: ThermalMonitor.describe(info.thermalState),
            buildConfiguration: buildConfiguration()
        )
    }

    private static func hardwareModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partial.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }

    private static func buildConfiguration() -> String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }
}
