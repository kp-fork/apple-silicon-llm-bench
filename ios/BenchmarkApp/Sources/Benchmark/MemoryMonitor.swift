import Foundation
import Darwin

/// Resident-memory sampling via Mach `task_info(MACH_TASK_BASIC_INFO)`.
///
/// We use this rather than `os_proc_available_memory()` because the resident size
/// is what jetsam looks at, and it is comparable across iOS versions.
public enum MemoryMonitor {
    /// Current resident memory in megabytes. Returns 0 on failure.
    public static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
}

/// Records peak resident memory across a sliding window.
public actor MemorySampler {
    private(set) var peakMB: Double = 0
    private var task: Task<Void, Never>?

    public init() {}

    public func start(intervalMS: Int = 100) {
        stop()
        peakMB = MemoryMonitor.residentMB()
        task = Task { [weak self] in
            while !Task.isCancelled {
                let current = MemoryMonitor.residentMB()
                await self?.bump(current)
                try? await Task.sleep(nanoseconds: UInt64(intervalMS) * 1_000_000)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func bump(_ value: Double) {
        if value > peakMB { peakMB = value }
    }
}
