import SwiftData
import SwiftUI

struct LetterboxdSyncView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var service: LetterboxdSyncService
  @AppStorage("letterboxd.username") private var savedUsername = ""
  @AppStorage("letterboxd.lastSync") private var lastSyncInterval: Double = 0
  @State private var username = ""
  @State private var showUndoConfirmation = false

  private var lastSyncText: String? {
    guard lastSyncInterval > 0 else { return nil }
    let date = Date(timeIntervalSince1970: lastSyncInterval)
    return date.formatted(date: .abbreviated, time: .shortened)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Connect Letterboxd")
                .font(.netflixSans(.bold, size: 30))
                .foregroundStyle(.white)

              Text("Import public watched films, watchlist entries, ratings, reviews, and favorites.")
                .font(.netflixSans(.medium, size: 15))
                .foregroundStyle(.gray)
            }

            VStack(alignment: .leading, spacing: 10) {
              Text("Username")
                .font(.netflixSans(.medium, size: 14))
                .foregroundStyle(.gray)

              TextField("letterboxd username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.netflixSans(.medium, size: 17))
                .foregroundStyle(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !service.progressMessage.isEmpty {
              HStack(spacing: 10) {
                if service.isSyncing {
                  ProgressView()
                    .tint(.white)
                }
                Text(service.progressMessage)
                  .font(.netflixSans(.medium, size: 14))
                  .foregroundStyle(.gray)
              }
            }

            if service.summary.totalHandled > 0 {
              syncSummary
            }

            if let error = service.errorMessage {
              Text(error)
                .font(.netflixSans(.medium, size: 14))
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 12) {
              Button {
                if service.isSyncing {
                  service.cancelSync()
                } else {
                  service.startSync(username: username)
                }
              } label: {
                Label(syncButtonTitle, systemImage: service.isSyncing ? "xmark" : "arrow.triangle.2.circlepath")
                  .font(.netflixSans(.bold, size: 16))
                  .frame(maxWidth: .infinity)
                  .padding()
              }
              .buttonStyle(.borderedProminent)
              .disabled(!service.isSyncing && username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

              if !savedUsername.isEmpty {
                Button(role: .destructive) {
                  showUndoConfirmation = true
                } label: {
                  Label("Undo Letterboxd Import", systemImage: "trash")
                    .font(.netflixSans(.medium, size: 16))
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
                .disabled(service.isSyncing)
              }
            }

            if let lastSyncText {
              Text("Last synced \(lastSyncText)")
                .font(.netflixSans(.medium, size: 13))
                .foregroundStyle(.gray)
            }
          }
          .padding(24)
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundStyle(.white)
        }
      }
      .onAppear {
        service.setModelContext(modelContext)
        if username.isEmpty {
          username = savedUsername
        }
      }
      .confirmationDialog(
        "Remove imported Letterboxd data?",
        isPresented: $showUndoConfirmation,
        titleVisibility: .visible
      ) {
        Button("Undo Import", role: .destructive) {
          service.undoImport()
          username = ""
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Manual Watchman data will be restored when possible.")
      }
    }
  }

  private var syncSummary: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Sync Summary")
        .font(.netflixSans(.bold, size: 18))
        .foregroundStyle(.white)

      HStack {
        summaryPill("Imported", service.summary.imported)
        summaryPill("Updated", service.summary.updated)
      }
      HStack {
        summaryPill("Needs Review", service.summary.failed)
        summaryPill("Skipped", service.summary.skipped)
      }
    }
    .padding()
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var syncButtonTitle: String {
    if service.isSyncing {
      return "Cancel Sync"
    }
    return savedUsername.isEmpty ? "Sync Letterboxd" : "Re-sync from Letterboxd"
  }

  private func summaryPill(_ label: String, _ value: Int) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(.gray)
      Spacer()
      Text("\(value)")
        .foregroundStyle(.white)
        .bold()
    }
    .font(.netflixSans(.medium, size: 14))
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.08))
    .clipShape(Capsule())
  }
}
