//
//  ProfileView.swift
//  documents
//

import SwiftUI

enum AppProfile {
    static let displayNameKey =
        "profile.displayName"
    static let defaultDisplayName =
        "Khairul"
}

struct ProfileView: View {
    @Binding var smartFolders: [FolderCardModel]
    var onFoldersChanged: (Set<String>) -> Void = {
        _ in
    }
    var onSignOut: () -> Void = { }

    @AppStorage(AppProfile.displayNameKey)
    private var displayName =
        AppProfile.defaultDisplayName
    @AppStorage(AppSettings.showsOrganisingStatus)
    private var showsOrganisingStatus = true
    @AppStorage(AppSettings.showsRecentlyOpened)
    private var showsRecentlyOpened = true
    @AppStorage(AppSettings.showsFolderItemCounts)
    private var showsFolderItemCounts = true

    @State private var confirmsSignOut = false
    @State private var isSigningOut = false

    var body: some View {
        Form {
            profileHeader

            Section("Account") {
                LabeledContent("Display name") {
                    TextField(
                        "Name",
                        text: $displayName
                    )
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(normaliseDisplayName)
                }
            }

            Section("Home") {
                Toggle(
                    "Show organising status",
                    isOn: $showsOrganisingStatus
                )

                Toggle(
                    "Show recently opened",
                    isOn: $showsRecentlyOpened
                )
            }

            Section("Smart Folders") {
                NavigationLink {
                    FolderSelectionView(
                        purpose: .manage,
                        onSave: updateFolders
                    )
                } label: {
                    LabeledContent(
                        "Folders",
                        value: "\(smartFolders.count) selected"
                    )
                }

                Toggle(
                    "Show item counts",
                    isOn: $showsFolderItemCounts
                )
            }

            Section("About") {
                LabeledContent(
                    "Version",
                    value: versionText
                )
            }

            Section {
                Button(
                    "Sign Out",
                    role: .destructive
                ) {
                    confirmsSignOut = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppPalette.background
                .ignoresSafeArea()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Sign out of Documents?",
            isPresented: $confirmsSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                isSigningOut = true
                onSignOut()
            }

            Button("Cancel", role: .cancel) { }
        }
        .onDisappear {
            if !isSigningOut {
                normaliseDisplayName()
            }
        }
    }

    private var profileHeader: some View {
        Section {
            HStack(spacing: 14) {
                Circle()
                    .fill(AppPalette.accent)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(initial)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(resolvedDisplayName)
                        .font(.headline)

                    Text("Documents profile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 5)
            .accessibilityElement(children: .combine)
        }
    }

    private var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty
            ? AppProfile.defaultDisplayName
            : trimmed
    }

    private var initial: String {
        String(resolvedDisplayName.prefix(1))
            .uppercased()
    }

    private var versionText: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String
            ?? "1.0"
        let build =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String
            ?? "1"

        return "\(version) (\(build))"
    }

    private func updateFolders(
        _ selectedIDs: Set<String>
    ) {
        smartFolders = FolderCardModel.customizedSamples
            .filter { folder in
                selectedIDs.contains(folder.id)
            }
        onFoldersChanged(selectedIDs)
    }

    private func normaliseDisplayName() {
        displayName = resolvedDisplayName
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            smartFolders: .constant(
                FolderCardModel.customizedSamples
            )
        )
    }
}
