//
//  ContentView.swift
//  documents
//
//  Created by Joseph Kevin Fredric on 16/8/26.
//
import SwiftUI
enum AppTab: Hashable {
    case home
    case browse
    case search
    case profile
}

enum BrowseRoute: Hashable {
    case folder(String)
    case needsReview
}
struct TabBar: View {
    var onSignOut: () -> Void = { }

    @StateObject private var library =
        DriveLibraryController()
    @State private var selectedTab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var browsePath: [BrowseRoute] = []
    var body: some View {
        Group {
            if selectedTab == .search {
                tabs
                    .searchable(
                        text: $searchText,
                        isPresented: $searchPresented,
                        prompt: "Search files and folders"
                    )
            } else {
                tabs
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .search {
                if oldValue != .search {
                    previousTab = oldValue
                }
                DispatchQueue.main.async {
                    searchPresented = true
                }
            } else {
                previousTab = newValue
                searchPresented = false
            }
        }
        .onChange(of: searchPresented) { _, isPresented in
            if !isPresented && selectedTab == .search {
                searchText = ""
                selectedTab = previousTab
            }
        }
        .tint(AppPalette.accent)
        .tabViewStyle(.automatic)
        .task {
            await library.synchronize()
        }
    }
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab(
                "Home",
                systemImage: "house.fill",
                value: AppTab.home
            ) {
                ContentView(
                    smartFolders: $library.smartFolders,
                    isOrganizing: library.isOrganizing,
                    organizingProgress:
                        library.organizingProgress,
                    organizedCount: library.organizedCount,
                    totalToOrganize:
                        library.totalToOrganize,
                    onFoldersChanged: {
                        Task {
                            await library.foldersChanged()
                        }
                    },
                    onOpenSmartFolder: { folderID in
                        browsePath = [.folder(folderID)]
                        selectedTab = .browse
                    },
                    onBrowseAll: {
                        browsePath = []
                        selectedTab = .browse
                    }
                )
            }
            Tab(
                "Browse",
                systemImage: "folder",
                value: AppTab.browse
            ) {
                BrowseView(
                    path: $browsePath,
                    smartFolders: $library.smartFolders,
                    filesByFolder: $library.filesByFolder,
                    needsReviewFiles:
                        $library.needsReviewFiles,
                    onMoveReviewFile: { file, folderID in
                        library.move(
                            file: file,
                            to: folderID
                        )
                    }
                )
            }
            Tab(
                "Profile",
                systemImage: "person.crop.circle",
                value: AppTab.profile
            ) {
                NavigationStack {
                    ProfileView(
                        smartFolders: $library.smartFolders,
                        onFoldersChanged: { _ in
                            Task {
                                await library.foldersChanged()
                            }
                        },
                        onSignOut: {
                            library.resetForSignOut()
                            onSignOut()
                        }
                    )
                }
            }
            Tab(
                value: AppTab.search,
                role: .search
            ) {
                NavigationStack {
                    UniversalSearchView(
                        searchText: searchText,
                        smartFolders: $library.smartFolders,
                        filesByFolder: $library.filesByFolder
                    )
                }
            }
        }
    }
}
struct UniversalSearchView: View {
    let searchText: String
    @Binding var smartFolders: [FolderCardModel]
    @Binding var filesByFolder: [String: [FolderFile]]
    @State private var previewedResult: SearchFileResult?
    private var folderIDs: [String] {
        if searchText.isEmpty {
            return smartFolders.map(\.id)
        }
        return smartFolders
            .filter { folder in
                folder.title.localizedCaseInsensitiveContains(searchText)
            }
            .map(\.id)
    }
    private var files: [SearchFileResult] {
        smartFolders.flatMap { folder in
            filesByFolder[folder.id, default: []].map { file in
                SearchFileResult(
                    folderID: folder.id,
                    file: file
                )
            }
        }
    }
    private var displayedFiles: [SearchFileResult] {
        if searchText.isEmpty {
            return files
        }
        return files.filter { result in
            result.file.name.localizedCaseInsensitiveContains(searchText)
            ||
            result.file.details.localizedCaseInsensitiveContains(searchText)
            ||
            folder(withID: result.folderID)?
                .title
                .localizedCaseInsensitiveContains(searchText)
                == true
        }
    }
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(
                        color: Color(
                            red: 0.860,
                            green: 0.925,
                            blue: 1.000
                        ),
                        location: 0
                    ),
                    .init(
                        color: Color(
                            red: 0.910,
                            green: 0.955,
                            blue: 1.000
                        ),
                        location: 0.52
                    ),
                    .init(
                        color: Color(
                            red: 0.950,
                            green: 0.976,
                            blue: 1.000
                        ),
                        location: 1
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if !folderIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Folders")
                                .font(.system(size: 19, weight: .medium))
                                .padding(.horizontal, 20)
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(folderIDs.enumerated()),
                                    id: \.element
                                ) { index, folderID in
                                    if let folderIndex =
                                        smartFolders.firstIndex(
                                            where: {
                                                $0.id == folderID
                                            }
                                        )
                                    {
                                        let folder =
                                            smartFolders[folderIndex]
                                        NavigationLink {
                                            DetailView(
                                                folder:
                                                    $smartFolders[
                                                        folderIndex
                                                    ],
                                                files: filesBinding(
                                                    for: folderID
                                                )
                                            )
                                        } label: {
                                            HStack(spacing: 16) {
                                                miniFolder(folder)
                                                VStack(
                                                    alignment: .leading,
                                                    spacing: 3
                                                ) {
                                                    Text(folder.title)
                                                        .font(
                                                            .system(
                                                                size: 16,
                                                                weight:
                                                                    .semibold
                                                            )
                                                        )
                                                        .foregroundStyle(
                                                            .black
                                                        )
                                                    Text(
                                                        "\(folder.itemCount) items"
                                                    )
                                                    .font(
                                                        .system(
                                                            size: 14,
                                                            weight: .medium
                                                        )
                                                    )
                                                    .foregroundStyle(
                                                        .secondary
                                                    )
                                                }
                                                Spacer()
                                                Image(
                                                    systemName:
                                                        "chevron.right"
                                                )
                                                .font(
                                                    .system(
                                                        size: 14,
                                                        weight: .semibold
                                                    )
                                                )
                                                .foregroundStyle(
                                                    .black.opacity(0.35)
                                                )
                                            }
                                            .padding(.horizontal, 18)
                                            .frame(height: 82)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        if index
                                            != folderIDs.count - 1
                                        {
                                            Divider()
                                                .opacity(0.25)
                                                .padding(.leading, 92)
                                        }
                                    }
                                }
                            }
                            .background {
                                RoundedRectangle(
                                    cornerRadius: 25,
                                    style: .continuous
                                )
                                .fill(.white.opacity(0.62))
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: 25,
                                        style: .continuous
                                    )
                                    .strokeBorder(
                                        .white.opacity(0.95),
                                        lineWidth: 1.2
                                    )
                                }
                                .shadow(
                                    color: .black.opacity(0.045),
                                    radius: 8,
                                    y: 3
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    if !displayedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Files")
                                .font(.system(size: 19, weight: .medium))
                                .padding(.horizontal, 20)
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(displayedFiles.enumerated()),
                                    id: \.element.id
                                ) { index, result in
                                    Button {
                                        previewedResult = result
                                    } label: {
                                        HStack(spacing: 13) {
                                            ZStack {
                                                RoundedRectangle(
                                                    cornerRadius: 11,
                                                    style: .continuous
                                                )
                                                .fill(.white.opacity(0.8))
                                                RoundedRectangle(
                                                    cornerRadius: 11,
                                                    style: .continuous
                                                )
                                                .strokeBorder(
                                                    .white.opacity(0.95),
                                                    lineWidth: 1
                                                )
                                                Image(
                                                    systemName: result.file.icon
                                                )
                                                .font(
                                                    .system(
                                                        size: 18,
                                                        weight: .semibold
                                                    )
                                                )
                                                .foregroundStyle(
                                                    result.file.color
                                                )
                                            }
                                            .frame(
                                                width: 45,
                                                height: 45
                                            )
                                            VStack(
                                                alignment: .leading,
                                                spacing: 3
                                            ) {
                                                Text(result.file.name)
                                                    .font(
                                                        .system(
                                                            size: 16,
                                                            weight: .medium
                                                        )
                                                    )
                                                    .foregroundStyle(.black)
                                                    .lineLimit(1)
                                                Text(
                                                    "\(folderTitle(for: result)) · \(result.file.details)"
                                                )
                                                .font(.system(size: 13))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 15)
                                        .frame(height: 73)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Opens file details")

                                    if index != displayedFiles.count - 1 {
                                        Divider()
                                            .opacity(0.25)
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                            .background {
                                RoundedRectangle(
                                    cornerRadius: 25,
                                    style: .continuous
                                )
                                .fill(.white.opacity(0.62))
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: 25,
                                        style: .continuous
                                    )
                                    .strokeBorder(
                                        .white.opacity(0.95),
                                        lineWidth: 1.2
                                    )
                                }
                                .shadow(
                                    color: .black.opacity(0.045),
                                    radius: 8,
                                    y: 3
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    if folderIDs.isEmpty && displayedFiles.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("No Results")
                                .font(
                                    .system(
                                        size: 18,
                                        weight: .semibold
                                    )
                                )
                            Text(
                                "No files or folders match “\(searchText)”"
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    }
                    Spacer()
                        .frame(height: 30)
                }
                .padding(.top, 20)
            }
        }
        .sheet(item: $previewedResult) { result in
            FilePreviewSheet(file: result.file)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func filesBinding(
        for folderID: String
    ) -> Binding<[FolderFile]> {
        Binding(
            get: {
                filesByFolder[folderID, default: []]
            },
            set: { files in
                filesByFolder[folderID] = files
            }
        )
    }
    private func folder(
        withID id: String
    ) -> FolderCardModel? {
        smartFolders.first { folder in
            folder.id == id
        }
    }
    private func folderTitle(
        for result: SearchFileResult
    ) -> String {
        folder(withID: result.folderID)?.title ?? ""
    }
    private func miniFolder(
        _ folder: FolderCardModel
    ) -> some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 7,
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                topTrailingRadius: 7,
                style: .continuous
            )
            .fill(folder.topColor)
            .frame(width: 30, height: 18)
            .offset(x: 2, y: 1)
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        folder.topColor,
                        folder.bottomColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 61, height: 44)
            .offset(y: 9)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 61, height: 44)
                .offset(y: 9)
            }
        }
        .frame(width: 61, height: 53)
        .shadow(
            color: folder.bottomColor.opacity(0.18),
            radius: 5,
            y: 3
        )
    }
}
enum FolderLibrary {
    private static let reviewAssignmentsKey =
        "needsReview.folderAssignments"

    static var initialFilesByFolder: [String: [FolderFile]] {
        var files = Dictionary(
            uniqueKeysWithValues:
                FolderCardModel.samples.map { folder in
                    (
                        folder.id,
                        sampleFiles(for: folder.id)
                    )
                }
        )

        for file in needsReviewSamples {
            guard let folderID = reviewAssignments[file.id],
                  files[folderID] != nil
            else {
                continue
            }

            files[folderID, default: []].append(file)
        }

        return files
    }

    static var initialNeedsReviewFiles: [FolderFile] {
        let folderIDs = Set(
            FolderCardModel.samples.map(\.id)
        )

        return needsReviewSamples.filter { file in
            guard let folderID = reviewAssignments[file.id] else {
                return true
            }

            return !folderIDs.contains(folderID)
        }
    }

    static var movedReviewCounts: [String: Int] {
        reviewAssignments.values.reduce(into: [:]) {
            counts,
            folderID in
            counts[folderID, default: 0] += 1
        }
    }

    static func saveMove(
        fileID: String,
        to folderID: String
    ) {
        var assignments = reviewAssignments
        assignments[fileID] = folderID
        UserDefaults.standard.set(
            assignments,
            forKey: reviewAssignmentsKey
        )
    }

    private static var reviewAssignments: [String: String] {
        UserDefaults.standard.dictionary(
            forKey: reviewAssignmentsKey
        ) as? [String: String] ?? [:]
    }

    private static let needsReviewSamples: [FolderFile] = [
        FolderFile(
            name: "Untitled Scan.pdf",
            details: "PDF document · 1.6 MB",
            date: "Today",
            icon: "doc.fill",
            color: .red
        ),
        FolderFile(
            name: "IMG_4821.jpg",
            details: "Image · 3.9 MB",
            date: "Today",
            icon: "photo.fill",
            color: .blue
        ),
        FolderFile(
            name: "Lecture Recording.m4a",
            details: "Audio · 12.4 MB",
            date: "Yesterday",
            icon: "waveform",
            color: .purple
        )
    ]

    private static func sampleFiles(
        for folderID: String
    ) -> [FolderFile] {
        switch folderID {
    case "school":
        return [
            FolderFile(
                name: "Biology Notes.pdf",
                details: "PDF document · 2.4 MB",
                date: "9:30 AM",
                icon: "doc.fill",
                color: .red
            ),
            FolderFile(
                name: "Essay Outline.docx",
                details: "Word document · 1.1 MB",
                date: "Yesterday",
                icon: "doc.text.fill",
                color: .blue
            ),
            FolderFile(
                name: "Physics Formulas.png",
                details: "Image · 3.2 MB",
                date: "Yesterday",
                icon: "photo.fill",
                color: .cyan
            ),
            FolderFile(
                name: "Study Guide.pdf",
                details: "PDF document · 1.8 MB",
                date: "Aug 14",
                icon: "doc.fill",
                color: .red
            ),
            FolderFile(
                name: "Class Presentation.pptx",
                details: "PowerPoint · 6.7 MB",
                date: "Aug 12",
                icon: "rectangle.fill.on.rectangle.fill",
                color: .orange
            )
        ]
    case "projects":
        return [
            FolderFile(
                name: "Project Proposal.key",
                details: "Keynote · 5.3 MB",
                date: "10:12 AM",
                icon: "rectangle.fill.on.rectangle.fill",
                color: .orange
            ),
            FolderFile(
                name: "Costs.numbers",
                details: "Numbers spreadsheet · 1.4 MB",
                date: "Yesterday",
                icon: "chart.bar.fill",
                color: .green
            ),
            FolderFile(
                name: "Mockup.png",
                details: "Image · 3.8 MB",
                date: "Aug 15",
                icon: "photo.fill",
                color: .blue
            ),
            FolderFile(
                name: "Research.pdf",
                details: "PDF document · 2.2 MB",
                date: "Aug 13",
                icon: "doc.fill",
                color: .red
            )
        ]
    case "personal":
        return [
            FolderFile(
                name: "Calendar.pdf",
                details: "PDF document · 1.2 MB",
                date: "Today",
                icon: "calendar",
                color: .green
            ),
            FolderFile(
                name: "Japan Itinerary.pdf",
                details: "PDF document · 2.8 MB",
                date: "Yesterday",
                icon: "airplane",
                color: .green
            ),
            FolderFile(
                name: "Japan Photos.jpg",
                details: "Image · 4.5 MB",
                date: "Aug 14",
                icon: "photo.fill",
                color: .orange
            ),
            FolderFile(
                name: "Japan Memories.mov",
                details: "Video · 18.6 MB",
                date: "Aug 12",
                icon: "play.rectangle.fill",
                color: .blue
            )
        ]
    case "design":
        return [
            FolderFile(
                name: "Brand Guidelines.pdf",
                details: "PDF document · 4.8 MB",
                date: "11:30 AM",
                icon: "doc.text.fill",
                color: .purple
            ),
            FolderFile(
                name: "Marks.ai",
                details: "Illustrator document · 3.1 MB",
                date: "Yesterday",
                icon: "paintpalette.fill",
                color: .purple
            ),
            FolderFile(
                name: "Concepts.jpg",
                details: "Image · 6.2 MB",
                date: "Aug 15",
                icon: "photo.fill",
                color: .indigo
            )
        ]
        default:
            return []
        }
    }
}
struct SearchFileResult: Identifiable {
    let folderID: String
    let file: FolderFile
    var id: String {
        "\(folderID)-\(file.id)"
    }
}
#Preview {
    TabBar()
}
struct FolderTint {
    var red: Double
    var green: Double
    var blue: Double

    init(
        red: Double,
        green: Double,
        blue: Double
    ) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    var color: Color {
        Color(
            red: red,
            green: green,
            blue: blue
        )
    }

    var rgb: (
        red: Double,
        green: Double,
        blue: Double
    ) {
        (red, green, blue)
    }
}
enum AppPalette {
    static let accent = Color(
        red: 0.32,
        green: 0.58,
        blue: 0.84
    )
    static let backgroundTop = Color(
        red: 0.91,
        green: 0.95,
        blue: 0.98
    )
    static let backgroundMiddle = Color(
        red: 0.95,
        green: 0.97,
        blue: 0.98
    )
    static let backgroundBottom = Color(
        red: 0.98,
        green: 0.985,
        blue: 0.985
    )
    static let schoolTop = FolderTint(
        red: 0.73,
        green: 0.86,
        blue: 0.95
    )
    static let schoolBottom = FolderTint(
        red: 0.52,
        green: 0.74,
        blue: 0.90
    )
    static let projectsTop = FolderTint(
        red: 0.94,
        green: 0.87,
        blue: 0.78
    )
    static let projectsBottom = FolderTint(
        red: 0.82,
        green: 0.70,
        blue: 0.57
    )
    static let personalTop = FolderTint(
        red: 0.77,
        green: 0.90,
        blue: 0.80
    )
    static let personalBottom = FolderTint(
        red: 0.57,
        green: 0.77,
        blue: 0.62
    )
    static let designTop = FolderTint(
        red: 0.88,
        green: 0.82,
        blue: 0.95
    )
    static let designBottom = FolderTint(
        red: 0.72,
        green: 0.60,
        blue: 0.85
    )
    static let softRed = Color(
        red: 0.88,
        green: 0.43,
        blue: 0.47
    )
    static let softBlue = Color(
        red: 0.34,
        green: 0.63,
        blue: 0.86
    )
    static let softGreen = Color(
        red: 0.42,
        green: 0.72,
        blue: 0.50
    )
    static let softOrange = Color(
        red: 0.90,
        green: 0.62,
        blue: 0.36
    )
    static let softPurple = Color(
        red: 0.68,
        green: 0.51,
        blue: 0.82
    )
    static let softTeal = Color(
        red: 0.35,
        green: 0.72,
        blue: 0.73
    )
    static let softIndigo = Color(
        red: 0.51,
        green: 0.54,
        blue: 0.81
    )
    static var background: LinearGradient {
        LinearGradient(
            stops: [
                .init(
                    color: backgroundTop,
                    location: 0
                ),
                .init(
                    color: backgroundMiddle,
                    location: 0.52
                ),
                .init(
                    color: backgroundBottom,
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
struct ContentView: View {
    @Binding var smartFolders: [FolderCardModel]
    let isOrganizing: Bool
    let organizingProgress: Double
    let organizedCount: Int
    let totalToOrganize: Int
    var onFoldersChanged: () -> Void = { }
    var onOpenSmartFolder: (String) -> Void = { _ in }
    var onBrowseAll: () -> Void = { }
    @State private var selectedFolderID: String?
    @State private var previewedRecentFile: FolderFile?
    @AppStorage(AppSettings.showsOrganisingStatus)
    private var showsOrganisingStatus = true
    @AppStorage(AppSettings.showsRecentlyOpened)
    private var showsRecentlyOpened = true
    @AppStorage(AppProfile.displayNameKey)
    private var profileDisplayName =
        AppProfile.defaultDisplayName
    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Good morning,")
                            Text(greetingDisplayName)
                        }
                        .font(.largeTitle.bold())
                        .tracking(-0.7)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 18)

                        HStack {
                            Text("Smart Folders")
                                .font(.system(size: 19, weight: .medium))
                            Spacer()
                            Button(action: onBrowseAll) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.horizontal, 20)
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(
                                Array(smartFolders.indices.prefix(4)),
                                id: \.self
                            ) { index in
                                HomeSmartFolderCard(
                                    folder: $smartFolders[index],
                                    onOpen: {
                                        onOpenSmartFolder(
                                            smartFolders[index].id
                                        )
                                    },
                                    onEdit: {
                                        withAnimation(
                                            .snappy(duration: 0.22)
                                        ) {
                                            selectedFolderID =
                                                smartFolders[index].id
                                        }
                                    }
                                )
                            }
                        }
                        if showsOrganisingStatus && isOrganizing {
                            VStack{
                                RoundedRectangle(cornerRadius: 16)
                                .fill(.gray.opacity(0.06))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            .gray.opacity(0.16),
                                            lineWidth: 0.5
                                        )
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 85)
                                .overlay(alignment: .topLeading) {
                                    VStack(
                                        alignment: .leading,
                                        spacing: 9
                                    ) {
                                        HStack {
                                            Text("Organising")
                                                .font(
                                                    .system(
                                                        size: 17,
                                                        weight: .semibold
                                                    )
                                                )
                                                .tracking(-0.3)
                                                .foregroundStyle(.black)
                                            Spacer()
                                            Text(
                                                "\(Int(organizingProgress * 100))%"
                                            )
                                                .font(
                                                    .system(
                                                        size: 13,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundStyle(.secondary)
                                        }
                                        ProgressView(
                                            value: organizingProgress
                                        )
                                            .tint(AppPalette.accent)
                                            .scaleEffect(
                                                x: 1,
                                                y: 0.8,
                                                anchor: .center
                                            )
                                        HStack {
                                            Text(
                                                "\(organizedCount) of \(totalToOrganize) files"
                                            )
                                                .font(
                                                    .system(
                                                        size: 13,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("Working…")
                                                .font(
                                                    .system(
                                                        size: 12,
                                                        weight: .medium
                                                    )
                                                )
                                                .foregroundStyle(
                                                    AppPalette.accent
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 12)
                                }
                                .padding(.horizontal, 20)
                                    .padding(.top, 20)
                            }
                        }
                        if showsRecentlyOpened {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                Text("Recently Opened")
                                    .font(.system(size: 19, weight: .medium))
                                Spacer()
                                Button(action: onBrowseAll) {
                                    Image(systemName: "chevron.right")
                                        .font(
                                            .system(
                                                size: 14,
                                                weight: .semibold
                                            )
                                        )
                                        .foregroundStyle(.gray)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            ScrollView(
                                .horizontal,
                                showsIndicators: false
                            ) {
                                HStack(spacing: 12) {
                                    if hasFolder("school") {
                                        RecentFileCard(
                                        title: "Biology Notes",
                                        type: "PDF",
                                        time: "12 min ago",
                                        icon: "doc.fill",
                                        color: AppPalette.softRed,
                                        action: {
                                            previewedRecentFile = FolderFile(
                                                name: "Biology Notes.pdf",
                                                details: "PDF document · 2.4 MB",
                                                date: "12 min ago",
                                                icon: "doc.fill",
                                                color: AppPalette.softRed
                                            )
                                        }
                                        )
                                    }

                                    if hasFolder("projects") {
                                        RecentFileCard(
                                        title: "Project Proposal",
                                        type: "KEY",
                                        time: "Yesterday",
                                        icon: "rectangle.fill.on.rectangle.fill",
                                        color: AppPalette.softOrange,
                                        action: {
                                            previewedRecentFile = FolderFile(
                                                name: "Project Proposal.key",
                                                details: "Keynote · 5.3 MB",
                                                date: "Yesterday",
                                                icon: "rectangle.fill.on.rectangle.fill",
                                                color: AppPalette.softOrange
                                            )
                                        }
                                        )
                                    }

                                    if hasFolder("personal") {
                                        RecentFileCard(
                                            title: "Travel Itinerary",
                                            type: "PDF",
                                            time: "Yesterday",
                                            icon: "airplane",
                                            color: AppPalette.softGreen,
                                            action: {
                                                previewedRecentFile = FolderFile(
                                                    name: "Travel Itinerary.pdf",
                                                    details: "PDF document · 2.8 MB",
                                                    date: "Yesterday",
                                                    icon: "airplane",
                                                    color: AppPalette.softGreen
                                                )
                                            }
                                        )
                                    }

                                    if hasFolder("design") {
                                        RecentFileCard(
                                        title: "Moodboard",
                                        type: "PNG",
                                        time: "Sunday",
                                        icon: "photo.fill",
                                        color: AppPalette.softBlue,
                                        action: {
                                            previewedRecentFile = FolderFile(
                                                name: "Moodboard.png",
                                                details: "Image · 6.2 MB",
                                                date: "Sunday",
                                                icon: "photo.fill",
                                                color: AppPalette.softBlue
                                            )
                                        }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .sheet(item: $previewedRecentFile) { file in
                FilePreviewSheet(file: file)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .overlay {
                if let selectedFolderID,
                   let index = smartFolders.firstIndex(
                    where: { $0.id == selectedFolderID }
                   ) {
                    SmartFolderEditorOverlay(
                        folder: $smartFolders[index],
                        onClose: {
                            smartFolders[index].saveCustomization()
                            onFoldersChanged()
                            withAnimation(
                                .snappy(duration: 0.22)
                            ) {
                                self.selectedFolderID = nil
                            }
                        }
                    )
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .bottom)
                        )
                    )
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var greetingDisplayName: String {
        let trimmed = profileDisplayName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        return trimmed.isEmpty
            ? AppProfile.defaultDisplayName
            : trimmed
    }

    private func hasFolder(_ id: String) -> Bool {
        smartFolders.contains { folder in
            folder.id == id
        }
    }
}
struct HomeSmartFolderCard: View {
    @Binding var folder: FolderCardModel
    let onOpen: () -> Void
    let onEdit: () -> Void
    var body: some View {
        ZStack {
            Button(action: onOpen) {
                GlassFolderView(
                    folder: $folder,
                    showsMenuButton: false
                )
            }
            .buttonStyle(.plain)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
            FolderEllipsisButton(
                action: onEdit
            )
        }
        .frame(maxWidth: 168)
        .aspectRatio(1, contentMode: .fit)
    }
}
struct SmartFolderEditorOverlay: View {
    @Binding var folder: FolderCardModel
    let onClose: () -> Void
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.10)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClose()
                    }
                SmartFolderEditPanel(
                    folder: $folder,
                    onDone: onClose
                )
                .frame(maxWidth: .infinity)
                .frame(
                    height: min(
                        proxy.size.height * 0.78,
                        680
                    )
                )
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 32,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 32,
                        style: .continuous
                    )
                    .fill(.ultraThinMaterial)
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 32,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 32,
                            style: .continuous
                        )
                        .strokeBorder(
                            Color.white.opacity(0.55),
                            lineWidth: 1
                        )
                    }
                    .shadow(
                        color: Color.black.opacity(0.10),
                        radius: 24,
                        y: -4
                    )
                }
            }
        }
    }
}
struct SmartFolderEditPanel: View {
    @Environment(\.self) private var environment
    @Binding var folder: FolderCardModel
    let onDone: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Capsule()
                    .fill(
                        Color.secondary.opacity(0.28)
                    )
                    .frame(
                        width: 38,
                        height: 5
                    )
                    .padding(.top, 9)
                VStack(spacing: 4) {
                    Text("Edit Smart Folder")
                        .font(
                            .system(
                                size: 24,
                                weight: .semibold
                            )
                        )
                        .tracking(-0.5)
                    Text(
                        "Choose a colour, this preview and the Home folder update together."
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                GlassFolderView(
                    folder: $folder,
                    showsMenuButton: false
                )
                .frame(
                    width: 190,
                    height: 190
                )
                .allowsHitTesting(false)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    Text("Name")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    TextField(
                        "Folder name",
                        text: $folder.title
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .medium
                        )
                    )
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
                }
                VStack(
                    alignment: .leading,
                    spacing: 7
                ) {
                    Text("Colour")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    ColorPicker(
                        "Folder colour",
                        selection: folderColor,
                        supportsOpacity: false
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .medium
                        )
                    )
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
                }
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background {
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(AppPalette.accent)
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    private var folderColor: Binding<Color> {
        Binding(
            get: {
                folder.editingTint.color
            },
            set: { color in
                let resolved = color.resolve(
                    in: environment
                )
                folder.customTint = FolderTint(
                    red: Double(resolved.red),
                    green: Double(resolved.green),
                    blue: Double(resolved.blue)
                )
            }
        )
    }
}
struct FolderEllipsisButton: View {
    let action: () -> Void
    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / 216,
                proxy.size.height / 216
            )
            let panelRightEdge = 206 * scale
            let matchingSidePadding = 16 * scale
            let menuRadius: CGFloat = 16
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                    Circle()
                        .stroke(
                            Color.white.opacity(0.58),
                            lineWidth: 1.2
                        )
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: 32, height: 32)
                .shadow(
                    color: Color.black.opacity(0.055),
                    radius: 3,
                    y: 1
                )
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .position(
                x:
                    panelRightEdge
                    - matchingSidePadding
                    - menuRadius,
                y: 164 * scale
            )
            .zIndex(20)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
struct RecentFileCard: View {
    let title: String
    let type: String
    let time: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.11))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Text(type)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(time)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .padding(14)
            .frame(width: 145, height: 115)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.64))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                .white.opacity(0.82),
                                lineWidth: 1.2
                            )
                    }
                    .shadow(
                        color: .black.opacity(0.035),
                        radius: 5,
                        y: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens file details")
    }
}
@ViewBuilder
private func fileTile(
    icon: String,
    color: Color
) -> some View {
    RoundedRectangle(cornerRadius: 12)
        .fill(.white.opacity(0.62))
        .frame(width: 44, height: 44)
        .overlay {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    .white.opacity(0.82),
                    lineWidth: 1
                )
        }
        .shadow(
            color: .black.opacity(0.03),
            radius: 3,
            y: 1
        )
}
struct FolderCardModel: Identifiable {
    let id: String
    var title: String
    var itemCount: Int
    private let baseTopTint: FolderTint
    private let baseBottomTint: FolderTint
    var customTint: FolderTint?
    var documents: [DocumentPreviewModel]
    init(
        id: String,
        title: String,
        itemCount: Int,
        topColor: FolderTint,
        bottomColor: FolderTint,
        documents: [DocumentPreviewModel]
    ) {
        self.id = id
        self.title = title
        self.itemCount = itemCount
        baseTopTint = topColor
        baseBottomTint = bottomColor
        customTint = nil
        self.documents = documents
    }
    var editingTint: FolderTint {
        customTint ?? baseBottomTint
    }
    var topColor: Color {
        (customTint ?? baseTopTint).color
    }
    var bottomColor: Color {
        (customTint ?? baseBottomTint).color
    }
    static let samples: [FolderCardModel] = [
        FolderCardModel(
            id: "school",
            title: "School",
            itemCount: 142,
            topColor: AppPalette.schoolTop,
            bottomColor: AppPalette.schoolBottom,
            documents: [
                DocumentPreviewModel(
                    id: "school-notes",
                    title: "Notes",
                    fileName: "History.docx",
                    symbol: "doc.text.fill",
                    accent: AppPalette.softBlue,
                    role: .leading
                ),
                DocumentPreviewModel(
                    id: "school-biology",
                    title: "Biology",
                    fileName: "Notes.pdf",
                    symbol: "book.closed.fill",
                    accent: AppPalette.softBlue,
                    role: .featured
                ),
                DocumentPreviewModel(
                    id: "school-photos",
                    title: "Field Trip",
                    fileName: "Photos.jpg",
                    symbol: "photo.fill",
                    accent: AppPalette.softTeal,
                    role: .trailing
                )
            ]
        ),
        FolderCardModel(
            id: "projects",
            title: "Projects",
            itemCount: 86,
            topColor: AppPalette.projectsTop,
            bottomColor: AppPalette.projectsBottom,
            documents: [
                DocumentPreviewModel(
                    id: "projects-budget",
                    title: "Budget",
                    fileName: "Costs.numbers",
                    symbol: "chart.bar.fill",
                    accent: AppPalette.softOrange,
                    role: .leading
                ),
                DocumentPreviewModel(
                    id: "projects-proposal",
                    title: "Project",
                    fileName: "Proposal.key",
                    symbol: "doc.text.fill",
                    accent: AppPalette.softOrange,
                    role: .featured
                ),
                DocumentPreviewModel(
                    id: "projects-mockup",
                    title: "Site",
                    fileName: "Mockup.png",
                    symbol: "photo.fill",
                    accent: AppPalette.softGreen,
                    role: .trailing
                )
            ]
        ),
        FolderCardModel(
            id: "personal",
            title: "Personal",
            itemCount: 64,
            topColor: AppPalette.personalTop,
            bottomColor: AppPalette.personalBottom,
            documents: [
                DocumentPreviewModel(
                    id: "personal-calendar",
                    title: "Plans",
                    fileName: "Calendar.pdf",
                    symbol: "calendar",
                    accent: AppPalette.softGreen,
                    role: .leading
                ),
                DocumentPreviewModel(
                    id: "personal-travel",
                    title: "Travel",
                    fileName: "Itinerary.pdf",
                    symbol: "airplane",
                    accent: AppPalette.softGreen,
                    role: .featured
                ),
                DocumentPreviewModel(
                    id: "personal-photos",
                    title: "Japan",
                    fileName: "Photos.jpg",
                    symbol: "photo.fill",
                    accent: AppPalette.softOrange,
                    role: .trailing
                )
            ]
        ),
        FolderCardModel(
            id: "design",
            title: "Design",
            itemCount: 37,
            topColor: AppPalette.designTop,
            bottomColor: AppPalette.designBottom,
            documents: [
                DocumentPreviewModel(
                    id: "design-marks",
                    title: "Logo",
                    fileName: "Marks.ai",
                    symbol: "paintpalette.fill",
                    accent: AppPalette.softPurple,
                    role: .leading
                ),
                DocumentPreviewModel(
                    id: "design-brand",
                    title: "Brand",
                    fileName: "Guidelines.pdf",
                    symbol: "doc.text.fill",
                    accent: AppPalette.softPurple,
                    role: .featured
                ),
                DocumentPreviewModel(
                    id: "design-moodboard",
                    title: "Moodboard",
                    fileName: "Concepts.jpg",
                    symbol: "photo.fill",
                    accent: AppPalette.softIndigo,
                    role: .trailing
                )
            ]
        )
    ]
}
private enum FolderCustomizationKeys {
    static func name(_ id: String) -> String {
        "smartFolder.\(id).name"
    }
    static func red(_ id: String) -> String {
        "smartFolder.\(id).red"
    }
    static func green(_ id: String) -> String {
        "smartFolder.\(id).green"
    }
    static func blue(_ id: String) -> String {
        "smartFolder.\(id).blue"
    }
    static func hasColor(_ id: String) -> String {
        "smartFolder.\(id).hasColor"
    }
}
extension FolderCardModel {
    static var customizedSamples: [FolderCardModel] {
        samples.map { folder in
            var customized =
                folder.applyingSavedCustomization()
            customized.itemCount +=
                FolderLibrary.movedReviewCounts[
                    folder.id,
                    default: 0
                ]
            return customized
        }
    }

    static var selectedCustomizedSamples: [FolderCardModel] {
        let selectedIDs = FolderSelectionStore.selectedIDs
        return customizedSamples.filter { folder in
            selectedIDs.contains(folder.id)
        }
    }
    func applyingSavedCustomization() -> FolderCardModel {
        let defaults = UserDefaults.standard
        var copy = self
        if let savedName = defaults.string(
            forKey: FolderCustomizationKeys.name(id)
        ) {
            let trimmed = savedName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmed.isEmpty {
                copy.title = trimmed
            }
        }
        if defaults.bool(
            forKey: FolderCustomizationKeys.hasColor(id)
        ) {
            copy.customTint = FolderTint(
                red: defaults.double(
                    forKey: FolderCustomizationKeys.red(id)
                ),
                green: defaults.double(
                    forKey: FolderCustomizationKeys.green(id)
                ),
                blue: defaults.double(
                    forKey: FolderCustomizationKeys.blue(id)
                )
            )
        }
        return copy
    }
    func saveCustomization() {
        let defaults = UserDefaults.standard
        defaults.set(
            title,
            forKey: FolderCustomizationKeys.name(id)
        )
        if let customTint {
            let rgb = customTint.rgb
            defaults.set(
                rgb.red,
                forKey: FolderCustomizationKeys.red(id)
            )
            defaults.set(
                rgb.green,
                forKey: FolderCustomizationKeys.green(id)
            )
            defaults.set(
                rgb.blue,
                forKey: FolderCustomizationKeys.blue(id)
            )
            defaults.set(
                true,
                forKey: FolderCustomizationKeys.hasColor(id)
            )
        }
    }
}
private enum BrowseFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case folders = "Folders"
    case documents = "Documents"
    case images = "Images"
    case videos = "Videos"

    var id: Self { self }
}

private enum BrowseSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case date = "Date"

    var id: Self { self }
}

private enum BrowseFileKind {
    case document
    case image
    case video
    case other

    init(fileName: String) {
        let fileExtension =
            fileName
                .split(separator: ".")
                .last?
                .lowercased() ?? ""

        if [
            "png", "jpg", "jpeg", "heic",
            "gif", "tiff", "webp"
        ].contains(fileExtension) {
            self = .image
        } else if [
            "mov", "mp4", "m4v", "avi",
            "mkv", "webm"
        ].contains(fileExtension) {
            self = .video
        } else if [
            "pdf", "doc", "docx", "pages",
            "ppt", "pptx", "key", "numbers",
            "xls", "xlsx", "csv", "txt",
            "rtf", "ai"
        ].contains(fileExtension) {
            self = .document
        } else {
            self = .other
        }
    }
}

private struct BrowseFileItem: Identifiable {
    let folderID: String?
    let folderTitle: String?
    let file: FolderFile

    var id: String {
        "\(folderID ?? "needs-review")|\(file.id)"
    }

    var kind: BrowseFileKind {
        BrowseFileKind(fileName: file.name)
    }
}

struct BrowseView: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var selectedFilter: BrowseFilter = .all
    @Binding var path: [BrowseRoute]
    @Binding var smartFolders: [FolderCardModel]
    @Binding var filesByFolder: [String: [FolderFile]]
    @Binding var needsReviewFiles: [FolderFile]
    var onMoveReviewFile: ((FolderFile, String) -> Void)?
    var searchText: String = ""

    private let filters: [BrowseFilter] = [
        .all,
        .folders,
        .documents,
        .images,
        .videos
    ]

    private var displayedFolders: [FolderCardModel] {
        let folders: [FolderCardModel]

        if searchText.isEmpty {
            folders = smartFolders
        } else {
            folders = smartFolders.filter { folder in
                folder.title.localizedCaseInsensitiveContains(
                    searchText
                )
                ||
                filesByFolder[folder.id, default: []].contains { file in
                    file.name.localizedCaseInsensitiveContains(
                        searchText
                    )
                    ||
                    file.details.localizedCaseInsensitiveContains(
                        searchText
                    )
                }
            }
        }

        return folders
    }

    private var folderFiles: [BrowseFileItem] {
        smartFolders.flatMap { folder in
            filesByFolder[folder.id, default: []].map { file in
                BrowseFileItem(
                    folderID: folder.id,
                    folderTitle: folder.title,
                    file: file
                )
            }
        }
    }

    private var searchedFolderFiles: [BrowseFileItem] {
        guard !searchText.isEmpty else {
            return folderFiles
        }

        return folderFiles.filter(matchesSearch)
    }

    private var visibleFiles: [BrowseFileItem] {
        switch selectedFilter {
        case .all:
            searchedFolderFiles
        case .documents:
            searchedFolderFiles.filter { $0.kind == .document }
        case .images:
            searchedFolderFiles.filter { $0.kind == .image }
        case .videos:
            searchedFolderFiles.filter { $0.kind == .video }
        case .folders:
            []
        }
    }

    private var hasVisibleResults: Bool {
        switch selectedFilter {
        case .all:
            !displayedFolders.isEmpty || !visibleFiles.isEmpty
        case .folders:
            !displayedFolders.isEmpty
        case .documents, .images, .videos:
            !visibleFiles.isEmpty
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        filterBar

                        needsReviewTab

                        if hasVisibleResults {
                            browseContent
                        } else {
                            emptyState
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(
                for: BrowseRoute.self
            ) { route in
                switch route {
                case .folder(let id):
                    if let folderIndex =
                        smartFolders.firstIndex(
                            where: { $0.id == id }
                        )
                    {
                        DetailView(
                            folder:
                                $smartFolders[
                                    folderIndex
                                ],
                            files: filesBinding(for: id),
                            searchText: searchText
                        )
                    }

                case .needsReview:
                    NeedsReviewView(
                        smartFolders: $smartFolders,
                        filesByFolder: $filesByFolder,
                        files: $needsReviewFiles,
                        onMove: onMoveReviewFile
                    )
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 9) {
                ForEach(filters) { filter in
                    filterButton(filter)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private func filterButton(
        _ filter: BrowseFilter
    ) -> some View {
        Button {
            withAnimation(
                reduceMotion
                ? nil
                : .snappy(duration: 0.25)
            ) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    selectedFilter == filter
                    ? .white.opacity(0.96)
                    : .black.opacity(0.62)
                )
                .padding(.horizontal, 17)
                .frame(height: 38)
                .background {
                    if selectedFilter == filter {
                        Capsule()
                            .fill(AppPalette.accent)
                            .shadow(
                                color:
                                    AppPalette.accent
                                        .opacity(0.12),
                                radius: 5,
                                y: 2
                            )
                    } else {
                        Capsule()
                            .fill(.white.opacity(0.46))
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        .white.opacity(0.68),
                                        lineWidth: 1
                                    )
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("\(filter.rawValue) filter")
        .accessibilityAddTraits(
            selectedFilter == filter
            ? .isSelected
            : []
        )
    }

    private var needsReviewTab: some View {
        NavigationLink(value: BrowseRoute.needsReview) {
            HStack(spacing: 14) {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(AppPalette.softOrange.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(AppPalette.softOrange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Needs Review")
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.black)

                    Text("\(needsReviewFiles.count) items")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.black.opacity(0.28)
                    )
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(.white.opacity(0.52))
                .shadow(
                    color: .black.opacity(0.03),
                    radius: 8,
                    y: 3
                )
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .accessibilityLabel(
            "Needs Review, \(needsReviewFiles.count) items"
        )
        .accessibilityHint(
            "Opens files that still need a folder"
        )
    }

    @ViewBuilder
    private var browseContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            switch selectedFilter {
            case .all:
                if !displayedFolders.isEmpty {
                    folderSection(
                        title: "Folders",
                        folders: displayedFolders
                    )
                }

                if !visibleFiles.isEmpty {
                    fileSection(
                        title: "Files",
                        files: visibleFiles
                    )
                }

            case .folders:
                folderSection(
                    title: "Folders",
                    folders: displayedFolders
                )

            case .documents, .images, .videos:
                fileSection(
                    title: selectedFilter.rawValue,
                    files: visibleFiles
                )
            }
        }
    }

    private func folderSection(
        title: String,
        folders: [FolderCardModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)

            VStack(spacing: 0) {
                ForEach(
                    Array(folders.enumerated()),
                    id: \.element.id
                ) { index, folder in
                    NavigationLink(
                        value: BrowseRoute.folder(folder.id)
                    ) {
                        HStack(spacing: 16) {
                            miniFolder(folder)

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(folder.title)
                                    .font(
                                        .system(
                                            size: 16,
                                            weight: .semibold
                                        )
                                    )
                                    .foregroundStyle(.black)

                                Text("\(folder.itemCount) items")
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .medium
                                        )
                                    )
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(
                                    Color.black.opacity(0.28)
                                )
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .frame(height: 91)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index != folders.count - 1 {
                        Divider()
                            .opacity(0.18)
                            .padding(.leading, 92)
                    }
                }
            }
            .background { listBackground }
            .padding(.horizontal, 20)
        }
    }

    private func fileSection(
        title: String,
        files: [BrowseFileItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)

            VStack(spacing: 0) {
                ForEach(
                    Array(files.enumerated()),
                    id: \.element.id
                ) { index, item in
                    FolderFileRow(file: item.file)

                    if index != files.count - 1 {
                        Divider()
                            .opacity(0.18)
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.vertical, 5)
            .background { listBackground }
            .padding(.horizontal, 20)
        }
    }

    private func sectionHeader(
        _ title: String
    ) -> some View {
        Text(title)
            .font(
                .system(
                    size: 19,
                    weight: .medium
                )
            )
            .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
            .font(.system(size: 28))
            .foregroundStyle(.secondary)

            Text(emptyTitle)
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )

            if !searchText.isEmpty {
                Text("No results for “\(searchText)”")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 38)
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .all:
            "Nothing here"
        case .folders:
            "No folders"
        case .documents:
            "No documents"
        case .images:
            "No images"
        case .videos:
            "No videos"
        }
    }

    private var listBackground: some View {
        RoundedRectangle(
            cornerRadius: 25,
            style: .continuous
        )
        .fill(.white.opacity(0.52))
        .overlay {
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .strokeBorder(
                .white.opacity(0.72),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.03),
            radius: 8,
            y: 3
        )
    }

    private func matchesSearch(
        _ item: BrowseFileItem
    ) -> Bool {
        item.file.name.localizedCaseInsensitiveContains(
            searchText
        )
        ||
        item.file.details.localizedCaseInsensitiveContains(
            searchText
        )
        ||
        item.folderTitle?
            .localizedCaseInsensitiveContains(searchText)
            == true
    }

    private func filesBinding(
        for folderID: String
    ) -> Binding<[FolderFile]> {
        Binding(
            get: {
                filesByFolder[folderID, default: []]
            },
            set: { files in
                filesByFolder[folderID] = files
            }
        )
    }

    private func miniFolder(
        _ folder: FolderCardModel
    ) -> some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 7,
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                topTrailingRadius: 7,
                style: .continuous
            )
            .fill(folder.topColor)
            .frame(width: 30, height: 18)
            .offset(x: 2, y: 1)

            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        folder.topColor,
                        folder.bottomColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 61, height: 44)
            .offset(y: 9)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.16),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 61, height: 44)
                .offset(y: 9)
            }
        }
        .frame(width: 61, height: 53)
        .shadow(
            color:
                folder.bottomColor.opacity(0.12),
            radius: 5,
            y: 3
        )
    }
}

struct NeedsReviewView: View {
    @Binding var smartFolders: [FolderCardModel]
    @Binding var filesByFolder: [String: [FolderFile]]
    @Binding var files: [FolderFile]
    var onMove: ((FolderFile, String) -> Void)?

    var body: some View {
        List {
            if files.isEmpty {
                ContentUnavailableView(
                    "Nothing to Review",
                    systemImage: "checkmark.circle",
                    description: Text(
                        "Every file has a folder."
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(files) { file in
                        HStack(spacing: 12) {
                            Image(systemName: file.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(file.color)
                                .frame(width: 36, height: 36)

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(file.name)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)

                                Text(file.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Menu {
                                ForEach(smartFolders) { folder in
                                    Button(folder.title) {
                                        move(
                                            file,
                                            to: folder
                                        )
                                    }
                                }
                            } label: {
                                Image(
                                    systemName: "folder.badge.plus"
                                )
                                .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .disabled(smartFolders.isEmpty)
                            .accessibilityLabel(
                                "Move \(file.name)"
                            )
                        }
                        .padding(.vertical, 5)
                    }
                } footer: {
                    Text(
                        "Choose a folder for each file."
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppPalette.background
                .ignoresSafeArea()
        }
        .navigationTitle("Needs Review")
        .navigationBarTitleDisplayMode(.large)
    }

    private func move(
        _ file: FolderFile,
        to folder: FolderCardModel
    ) {
        if let onMove {
            onMove(file, folder.id)
            return
        }

        guard let fileIndex = files.firstIndex(
            where: { $0.id == file.id }
        ) else {
            return
        }

        let movedFile = files.remove(at: fileIndex)
        filesByFolder[folder.id, default: []].append(
            movedFile
        )

        if let folderIndex = smartFolders.firstIndex(
            where: { $0.id == folder.id }
        ) {
            smartFolders[folderIndex].itemCount += 1
        }

        FolderLibrary.saveMove(
            fileID: file.id,
            to: folder.id
        )
    }
}

struct DetailView: View {
    @Binding var folder: FolderCardModel
    @Binding var files: [FolderFile]
    var searchText: String = ""
    @State private var sortOption: BrowseSortOption = .name
    @State private var sortAscending = true

    private var displayedFiles: [FolderFile] {
        let filteredFiles: [FolderFile]

        if searchText.isEmpty
            || folder.title.localizedCaseInsensitiveContains(
                searchText
            ) {
            filteredFiles = files
        } else {
            filteredFiles = files.filter { file in
                file.name.localizedCaseInsensitiveContains(
                    searchText
                )
                ||
                file.details.localizedCaseInsensitiveContains(
                    searchText
                )
            }
        }

        let sorted = filteredFiles.sorted(by: compareFiles)

        return sortAscending
            ? sorted
            : Array(sorted.reversed())
    }
    var body: some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 28)
                    GlassFolderView(
                        folder: $folder,
                        showsMenuButton: false
                    )
                    .frame(
                        width: 300,
                        height: 300
                    )
                    HStack {
                        Text("Contents")
                            .font(
                                .system(
                                    size: 19,
                                    weight: .medium
                                )
                            )
                        Spacer()
                        Menu {
                            Picker(
                                "Sort by",
                                selection: $sortOption
                            ) {
                                ForEach(
                                    BrowseSortOption.allCases
                                ) { option in
                                    Text(option.rawValue)
                                        .tag(option)
                                }
                            }

                            Button {
                                sortAscending.toggle()
                            } label: {
                                Label(
                                    sortAscending
                                        ? "Descending order"
                                        : "Ascending order",
                                    systemImage:
                                        sortAscending
                                        ? "arrow.down"
                                        : "arrow.up"
                                )
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(sortOption.rawValue)
                                Image(
                                    systemName:
                                        "chevron.down"
                                )
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .semibold
                                    )
                                )
                            }
                            .font(
                                .system(
                                    size: 13,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .frame(
                                width: 82,
                                height: 36
                            )
                            .glassEffect(
                                .regular.interactive(),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                    if displayedFiles.isEmpty {
                        VStack(spacing: 8) {
                            Image(
                                systemName:
                                    "magnifyingglass"
                            )
                            .font(.system(size: 27))
                            .foregroundStyle(
                                .secondary
                            )
                            Text("No files found")
                                .font(
                                    .system(
                                        size: 16,
                                        weight: .semibold
                                    )
                                )
                            Text(
                                "No results for “\(searchText)”"
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 55)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(
                                Array(
                                    displayedFiles.enumerated()
                                ),
                                id: \.element.id
                            ) { index, file in
                                FolderFileRow(
                                    file: file
                                )
                                if index !=
                                    displayedFiles.count - 1
                                {
                                    Divider()
                                        .opacity(0.18)
                                        .padding(
                                            .leading,
                                            70
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(
                                cornerRadius: 25,
                                style: .continuous
                            )
                            .fill(
                                .white.opacity(0.52)
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 25,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    .white.opacity(0.72),
                                    lineWidth: 1
                                )
                            }
                            .shadow(
                                color:
                                    .black.opacity(
                                        0.03
                                    ),
                                radius: 8,
                                y: 3
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    Spacer()
                        .frame(height: 20)
                }
            }
        }
        .navigationTitle(folder.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func compareFiles(
        _ lhs: FolderFile,
        _ rhs: FolderFile
    ) -> Bool {
        switch sortOption {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
                == .orderedAscending

        case .date:
            let lhsIndex = files.firstIndex {
                $0.id == lhs.id
            } ?? 0
            let rhsIndex = files.firstIndex {
                $0.id == rhs.id
            } ?? 0
            return lhsIndex < rhsIndex

        }
    }
}
struct FolderFile: Identifiable {
    let id: String
    let name: String
    let details: String
    let date: String
    let icon: String
    let color: Color
    let modifiedDate: Date?
    let webURL: URL?

    init(
        id: String? = nil,
        name: String,
        details: String,
        date: String,
        icon: String,
        color: Color,
        modifiedDate: Date? = nil,
        webURL: URL? = nil
    ) {
        self.id = id ?? "\(name)|\(details)"
        self.name = name
        self.details = details
        self.date = date
        self.icon = icon
        self.color = color
        self.modifiedDate = modifiedDate
        self.webURL = webURL
    }
}
struct FolderFileRow: View {
    let file: FolderFile
    @State private var showsPreview = false

    var body: some View {
        Button {
            showsPreview = true
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 11,
                        style: .continuous
                    )
                    .fill(.white.opacity(0.68))

                    Image(systemName: file.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(file.color)
                }
                .frame(width: 45, height: 45)

                Text(file.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(file.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 15)
        .frame(height: 73)
        .accessibilityHint("Opens file details")
        .sheet(isPresented: $showsPreview) {
            FilePreviewSheet(file: file)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

struct FilePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let file: FolderFile

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        "Name",
                        value: file.name
                    )

                    LabeledContent(
                        "Date",
                        value: file.date
                    )
                }

                Section {
                    Button("Done") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollContentBackground(.hidden)
            .background {
                AppPalette.background
                    .ignoresSafeArea()
            }
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppPalette.accent)
    }
}
struct DocumentPreviewModel: Identifiable {
    let id: String
    let title: String
    let fileName: String
    let symbol: String
    let accent: Color
    let role: DocumentRole
}
enum DocumentRole {
    case leading
    case featured
    case trailing
}
struct GlassFolderView: View {
    @Binding var folder: FolderCardModel
    var showsMenuButton: Bool = true
    var onMenu: () -> Void = { }
    @AppStorage(AppSettings.showsFolderItemCounts)
    private var showsFolderItemCounts = true
    var body: some View {
        GeometryReader { proxy in
            let scale =
                min(
                    proxy.size.width / 216,
                    proxy.size.height / 216
                )
            let panelRightEdge =
                206 * scale
            let matchingSidePadding =
                16 * scale
            let menuRadius: CGFloat = 16
            folderArtwork
                .frame(
                    width: 216,
                    height: 216,
                    alignment: .topLeading
                )
                .scaleEffect(
                    scale,
                    anchor: .topLeading
                )
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
                .overlay(
                    alignment: .topLeading
                ) {
                    if showsMenuButton {
                        menuButton
                            .position(
                                x:
                                    panelRightEdge
                                    - matchingSidePadding
                                    - menuRadius,
                                y: 164 * scale
                            )
                    }
                }
        }
        .aspectRatio(
            1,
            contentMode: .fit
        )
        .accessibilityElement(
            children: .contain
        )
        .accessibilityLabel(
            "\(folder.title) folder, \(folder.itemCount) items"
        )
    }
    private var folderArtwork: some View {
        let panelShape =
            UnevenRoundedRectangle(
                topLeadingRadius: 21,
                bottomLeadingRadius: 27,
                bottomTrailingRadius: 27,
                topTrailingRadius: 21,
                style: .continuous
            )
        return ZStack(
            alignment: .topLeading
        ) {
            FolderBackShape()
                .fill(
                    LinearGradient(
                        colors: [
                            folder.topColor,
                            folder.bottomColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 196,
                    height: 80
                )
                .shadow(
                    color:
                        folder.bottomColor
                            .opacity(0.08),
                    radius: 6,
                    y: 3
                )
                .offset(
                    x: 10,
                    y: 76
                )
            ForEach(folder.documents) {
                document in
                FakeDocumentView(
                    document: document
                )
                .frame(
                    width:
                        document.role.size.width,
                    height:
                        document.role.size.height
                )
                .rotationEffect(
                    .degrees(
                        document.role.rotation
                    )
                )
                .shadow(
                    color:
                        Color.black.opacity(
                            0.07
                        ),
                    radius: 7,
                    y: 5
                )
                .position(
                    document.role.position
                )
                .zIndex(
                    document.role == .featured
                    ? 3
                    : 2
                )
            }
            panelShape
                .fill(
                    LinearGradient(
                        colors: [
                            folder.topColor,
                            folder.bottomColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 196,
                    height: 112
                )
                .overlay {
                    Image("rectamgle")
                        .resizable()
                        .frame(
                            width: 342,
                            height: 259
                        )
                        .offset(
                            x: -18,
                            y: -4
                        )
                        .blendMode(.softLight)
                        .opacity(0.20)
                        .accessibilityHidden(
                            true
                        )
                }
                .clipShape(panelShape)
                .overlay {
                    panelShape
                        .stroke(
                            Color.white.opacity(
                                0.18
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color:
                        folder.bottomColor
                            .opacity(0.12),
                    radius: 10,
                    y: 6
                )
                .offset(
                    x: 10,
                    y: 94
                )
                .zIndex(4)
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(folder.title)
                    .font(
                        .system(
                            size: 21,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.black.opacity(
                            0.82
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if showsFolderItemCounts {
                    Text(
                        "\(folder.itemCount) items"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.black.opacity(
                            0.46
                        )
                    )
                }
            }
            .offset(
                x: 26,
                y: 140
            )
            .zIndex(5)
        }
    }
    private var menuButton: some View {
        Button(action: onMenu) {
            menuButtonLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options for \(folder.title)")
    }
    private var menuButtonLabel: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.24))
            Circle()
                .stroke(
                    Color.white.opacity(0.58),
                    lineWidth: 1.2
                )
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: 32, height: 32)
        .shadow(
            color: Color.black.opacity(0.055),
            radius: 3,
            y: 1
        )
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}
private struct FolderBackShape: Shape {
    func path(
        in rect: CGRect
    ) -> Path {
        var path = Path()
        path.move(
            to: CGPoint(
                x: 0,
                y: 25
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 18,
                y: 0
            ),
            control1: CGPoint(
                x: 0,
                y: 11
            ),
            control2: CGPoint(
                x: 7,
                y: 0
            )
        )
        path.addLine(
            to: CGPoint(
                x: 61,
                y: 0
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 82,
                y: 22
            ),
            control1: CGPoint(
                x: 72,
                y: 0
            ),
            control2: CGPoint(
                x: 74,
                y: 12
            )
        )
        path.addLine(
            to: CGPoint(
                x: rect.width - 18,
                y: 22
            )
        )
        path.addCurve(
            to: CGPoint(
                x: rect.width,
                y: 40
            ),
            control1: CGPoint(
                x: rect.width - 8,
                y: 22
            ),
            control2: CGPoint(
                x: rect.width,
                y: 30
            )
        )
        path.addLine(
            to: CGPoint(
                x: rect.width,
                y: rect.height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0,
                y: rect.height
            )
        )
        path.closeSubpath()
        return path
    }
}
private struct FakeDocumentView: View {
    let document: DocumentPreviewModel
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .fill(
                Color(
                    red: 0.985,
                    green: 0.982,
                    blue: 0.975
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(
                        0.78
                    ),
                    lineWidth: 1
                )
            }
            documentContent
        }
    }
    @ViewBuilder
    private var documentContent: some View {
        switch document.role {
        case .leading:
            RoundedRectangle(
                cornerRadius: 5,
                style: .continuous
            )
            .fill(document.accent.gradient)
            .frame(
                width: 21,
                height: 25
            )
            .overlay {
                Image(
                    systemName:
                        document.symbol
                )
                .font(
                    .system(
                        size: 10,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.9)
                )
            }
            .offset(
                x: 12,
                y: 18
            )
        case .featured:
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(document.title)
                Text(document.fileName)
                Capsule()
                    .fill(
                        Color.gray.opacity(
                            0.10
                        )
                    )
                    .frame(
                        width: 73,
                        height: 3
                    )
                    .padding(.top, 8)
                Capsule()
                    .fill(
                        Color.gray.opacity(
                            0.07
                        )
                    )
                    .frame(
                        width: 54,
                        height: 3
                    )
            }
            .font(
                .system(
                    size: 11.5,
                    weight: .medium,
                    design: .rounded
                )
            )
            .foregroundStyle(
                Color.black.opacity(
                    0.70
                )
            )
            .offset(
                x: 14,
                y: 13
            )
        case .trailing:
            VStack {
                Spacer()
                RoundedRectangle(
                    cornerRadius: 6,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            document.accent
                                .opacity(0.32),
                            document.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 38,
                    height: 31
                )
                .overlay {
                    Image(
                        systemName:
                            document.symbol
                    )
                    .font(
                        .system(size: 14)
                    )
                    .foregroundStyle(
                        .white.opacity(0.78)
                    )
                }
                .padding(.bottom, 8)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
    }
}
private extension DocumentRole {
    var size: CGSize {
        switch self {
        case .leading:
            CGSize(
                width: 61,
                height: 82
            )
        case .featured:
            CGSize(
                width: 118,
                height: 92
            )
        case .trailing:
            CGSize(
                width: 62,
                height: 84
            )
        }
    }
    var position: CGPoint {
        switch self {
        case .leading:
            CGPoint(
                x: 41,
                y: 67
            )
        case .featured:
            CGPoint(
                x: 110,
                y: 58
            )
        case .trailing:
            CGPoint(
                x: 172,
                y: 79
            )
        }
    }
    var rotation: Double {
        switch self {
        case .leading:
            -3
        case .featured:
            5
        case .trailing:
            7
        }
    }
}
