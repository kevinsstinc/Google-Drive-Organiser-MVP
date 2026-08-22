//
//  FolderSelectionView.swift
//  documents
//

import SwiftUI

enum FolderSelectionStore {
    private static let selectedIDsKey =
        "folders.selectedIDs"

    static var hasSelection: Bool {
        guard let savedIDs = UserDefaults.standard.stringArray(
            forKey: selectedIDsKey
        ) else {
            return false
        }

        let validIDs = Set(
            FolderCardModel.samples.map(\.id)
        )
        return savedIDs.contains { validIDs.contains($0) }
    }

    static var selectedIDs: Set<String> {
        let allIDs = Set(
            FolderCardModel.samples.map(\.id)
        )

        guard let savedIDs = UserDefaults.standard.stringArray(
            forKey: selectedIDsKey
        ) else {
            return allIDs
        }

        let validIDs = Set(savedIDs)
            .intersection(allIDs)
        return validIDs.isEmpty ? allIDs : validIDs
    }

    static func save(_ selectedIDs: Set<String>) {
        let orderedIDs = FolderCardModel.samples
            .map(\.id)
            .filter(selectedIDs.contains)

        UserDefaults.standard.set(
            orderedIDs,
            forKey: selectedIDsKey
        )
    }

    static func clear() {
        UserDefaults.standard.removeObject(
            forKey: selectedIDsKey
        )
    }
}

enum FolderSelectionPurpose {
    case onboarding
    case manage
}

struct FolderSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let purpose: FolderSelectionPurpose
    let onSave: (Set<String>) -> Void
    var onCancel: (() -> Void)? = nil

    @State private var selectedIDs: Set<String>

    init(
        purpose: FolderSelectionPurpose,
        onSave: @escaping (Set<String>) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.purpose = purpose
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedIDs = State(
            initialValue: FolderSelectionStore.selectedIDs
        )
    }

    var body: some View {
        List {
            Section {
                ForEach(FolderCardModel.customizedSamples) { folder in
                    Button {
                        toggle(folder.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.title3)
                                .foregroundStyle(folder.bottomColor)
                                .frame(width: 32)

                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text(folder.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(description(for: folder.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(
                                systemName: selectedIDs.contains(folder.id)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.title3)
                            .foregroundStyle(
                                selectedIDs.contains(folder.id)
                                    ? AppPalette.accent
                                    : Color.secondary
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        selectedIDs.contains(folder.id)
                            ? .isSelected
                            : []
                    )
                }
            } header: {
                Text("Smart Folders")
            } footer: {
                Text(
                    "Pick at least one. You can change this later in Profile."
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppPalette.background
                .ignoresSafeArea()
        }
        .navigationTitle("Choose Folders")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    save()
                } label: {
                    Text(actionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedIDs.isEmpty)

                if let onCancel {
                    Button("Use Another Account") {
                        onCancel()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 36)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var actionTitle: String {
        purpose == .onboarding
            ? "Continue"
            : "Save"
    }

    private func toggle(_ folderID: String) {
        if selectedIDs.contains(folderID) {
            selectedIDs.remove(folderID)
        } else {
            selectedIDs.insert(folderID)
        }
    }

    private func save() {
        guard !selectedIDs.isEmpty else {
            return
        }

        FolderSelectionStore.save(selectedIDs)
        onSave(selectedIDs)

        if purpose == .manage {
            dismiss()
        }
    }

    private func description(
        for folderID: String
    ) -> String {
        switch folderID {
        case "school":
            "Notes and coursework"
        case "projects":
            "Plans and active work"
        case "personal":
            "Travel and personal files"
        case "design":
            "Brand and creative work"
        default:
            "Organised documents"
        }
    }
}

#Preview {
    NavigationStack {
        FolderSelectionView(
            purpose: .onboarding,
            onSave: { _ in }
        )
    }
}
