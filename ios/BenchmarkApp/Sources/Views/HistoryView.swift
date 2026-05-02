import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        List {
            if session.history.isEmpty {
                ContentUnavailableView(
                    "No runs yet",
                    systemImage: "tray",
                    description: Text("Tap Run on the Run tab to record your first benchmark.")
                )
            } else {
                ForEach(session.history) { result in
                    NavigationLink(destination: ResultDetailView(result: result)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(result.runtime).font(.headline)
                                Spacer()
                                Text(result.task).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(result.model.displayName)
                                .font(.subheadline)
                            HStack {
                                Label(String(format: "%.1f tok/s", result.metrics.decodeTokensPerSecond), systemImage: "speedometer")
                                Label("\(result.metrics.firstTokenLatencyMS) ms", systemImage: "timer")
                                Label("\(Int(result.metrics.memoryPeakDuringDecodeMB)) MB", systemImage: "memorychip")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Task {
                            try? await ResultStore.shared.clear()
                            await session.reloadHistory()
                        }
                    } label: {
                        Label("Clear all", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await session.reloadHistory()
        }
    }
}
