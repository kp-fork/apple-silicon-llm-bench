import Foundation
import HuggingFace

/// Shared helper that downloads a HuggingFace repo (or a subset of it) into
/// the app's `Documents/models/<runtime>/<repo-id>/` directory. Used by every
/// runtime adapter that does not have its own download mechanism.
public enum HFDownloader {
    public static func snapshot(
        for model: ModelInfo,
        runtime: RuntimeKind,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        let target = modelDirectory(runtime: runtime, hfRepoId: model.hfRepoId)

        // Already downloaded?
        if FileManager.default.fileExists(atPath: target.path),
           let contents = try? FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: nil),
           !contents.isEmpty {
            progress(1)
            return target
        }

        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        guard let repoID = HuggingFace.Repo.ID(rawValue: model.hfRepoId) else {
            throw LLMRuntimeError.downloadFailed("Invalid HF repo id: \(model.hfRepoId)")
        }

        do {
            let downloaded = try await HubClient.default.downloadSnapshot(
                of: repoID,
                revision: "main",
                matching: model.hfFilePatterns,
                progressHandler: { @MainActor p in
                    progress(p.fractionCompleted)
                }
            )
            // The HubClient downloads into its own cache. Mirror primary file(s) into target.
            // For runtimes that need a stable path, use the HubClient cache directly.
            return downloaded
        } catch {
            throw LLMRuntimeError.downloadFailed(error.localizedDescription)
        }
    }

    public static func modelDirectory(runtime: RuntimeKind, hfRepoId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(runtime.rawValue, isDirectory: true)
            .appendingPathComponent(hfRepoId.replacingOccurrences(of: "/", with: "__"), isDirectory: true)
    }
}
