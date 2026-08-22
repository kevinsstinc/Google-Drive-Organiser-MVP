////
////  TabBar.swift
////  documents
////
////  Created by Joseph Kevin Fredric on 17/8/26.
////
//import SwiftUI
//
//enum AppTab: Hashable {
//    case home
//    case browse
//    case search
//}
//
//@MainActor
//struct TabBar: View {
//
//    @State private var didInitialSync = false
//
//    @State private var selectedTab: AppTab = .home
//    @State private var previousTab: AppTab = .home
//
//    @State private var drive = GoogleDriveManager()
//    @State private var store = DocumentStore()
//
//    @State private var searchText = ""
//    @State private var searchPresented = false
//
//    @State private var currentFolder: FolderCardModel?
//
//    var body: some View {
//        Group {
//            if selectedTab == .search {
//                tabs
//                    .searchable(
//                        text: $searchText,
//                        isPresented: $searchPresented,
//                        prompt: "Search files and folders"
//                    )
//            } else {
//                tabs
//            }
//        }
//        .task {
//            guard !didInitialSync else {
//                return
//            }
//
//            didInitialSync = true
//
//            await drive.restoreSignIn()
//
//            guard drive.isSignedIn else {
//                return
//            }
//
//            await drive.loadFiles()
//
//            guard !drive.files.isEmpty else {
//                return
//            }
//
//            await store.organize(
//                files: drive.files
//            )
//        }
//        .onChange(of: selectedTab) {
//            oldValue,
//            newValue in
//
//            if newValue == .search {
//                if oldValue != .search {
//                    previousTab = oldValue
//                }
//
//                DispatchQueue.main.async {
//                    searchPresented = true
//                }
//            } else {
//                previousTab = newValue
//                searchPresented = false
//            }
//        }
//        .onChange(of: searchPresented) {
//            _,
//            isPresented in
//
//            if !isPresented &&
//                selectedTab == .search {
//
//                searchText = ""
//                selectedTab = previousTab
//            }
//        }
//        .tint(AppPalette.accent)
//        .tabViewStyle(.automatic)
//    }
//
//    private var tabs: some View {
//        TabView(
//            selection: $selectedTab
//        ) {
//            Tab(
//                "Home",
//                systemImage: "house.fill",
//                value: AppTab.home
//            ) {
//                ContentView(
//                    drive: drive,
//                    store: store
//                )
//            }
//
//            Tab(
//                "Browse",
//                systemImage: "folder",
//                value: AppTab.browse
//            ) {
//                BrowseView(
//                    currentFolder: $currentFolder,
//                    drive: drive,
//                    store: store
//                )
//            }
//
//            Tab(
//                value: AppTab.search,
//                role: .search
//            ) {
//                NavigationStack {
//                    UniversalSearchView(
//                        searchText: searchText,
//                        store: store
//                    )
//                }
//            }
//        }
//    }
//}
//
//@MainActor
//struct UniversalSearchView: View {
//
//    let searchText: String
//    let store: DocumentStore
//
//    @Environment(\.openURL)
//    private var openURL
//
//    private var trimmedSearch: String {
//        searchText
//            .trimmingCharacters(
//                in: .whitespacesAndNewlines
//            )
//    }
//
//    private var folders: [FolderCardModel] {
//        guard !trimmedSearch.isEmpty else {
//            return []
//        }
//
//        return store.folders.filter {
//            folder in
//
//            if folder.title
//                .localizedCaseInsensitiveContains(
//                    trimmedSearch
//                ) {
//                return true
//            }
//
//            return store.files(
//                for: folder
//            )
//            .contains {
//                file in
//
//                file.name
//                    .localizedCaseInsensitiveContains(
//                        trimmedSearch
//                    )
//            }
//        }
//    }
//
//    private var files: [SearchFileResult] {
//        store.folders.flatMap {
//            folder in
//
//            store.files(
//                for: folder
//            )
//            .map {
//                file in
//
//                SearchFileResult(
//                    folder: folder,
//                    file: file
//                )
//            }
//        }
//    }
//
//    private var displayedFiles: [SearchFileResult] {
//        guard !trimmedSearch.isEmpty else {
//            return []
//        }
//
//        return files.filter {
//            result in
//
//            result.file.name
//                .localizedCaseInsensitiveContains(
//                    trimmedSearch
//                )
//            ||
//            result.file.details
//                .localizedCaseInsensitiveContains(
//                    trimmedSearch
//                )
//            ||
//            result.folder.title
//                .localizedCaseInsensitiveContains(
//                    trimmedSearch
//                )
//        }
//    }
//
//    var body: some View {
//        ZStack {
//            LinearGradient(
//                stops: [
//                    .init(
//                        color: Color(
//                            red: 0.860,
//                            green: 0.925,
//                            blue: 1.000
//                        ),
//                        location: 0
//                    ),
//                    .init(
//                        color: Color(
//                            red: 0.910,
//                            green: 0.955,
//                            blue: 1.000
//                        ),
//                        location: 0.52
//                    ),
//                    .init(
//                        color: Color(
//                            red: 0.950,
//                            green: 0.976,
//                            blue: 1.000
//                        ),
//                        location: 1
//                    )
//                ],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .ignoresSafeArea()
//
//            if trimmedSearch.isEmpty {
//                emptySearchView
//            } else {
//                searchResults
//            }
//        }
//        .toolbarBackground(
//            .hidden,
//            for: .navigationBar
//        )
//    }
//
//    private var emptySearchView: some View {
//        VStack(spacing: 10) {
//            Image(
//                systemName:
//                    "magnifyingglass"
//            )
//            .font(
//                .system(
//                    size: 34
//                )
//            )
//            .foregroundStyle(
//                .secondary
//            )
//
//            Text("Search your Drive")
//                .font(
//                    .system(
//                        size: 18,
//                        weight: .semibold
//                    )
//                )
//                .foregroundStyle(
//                    .black
//                )
//
//            Text(
//                "Find files or smart folders"
//            )
//            .font(
//                .system(
//                    size: 14
//                )
//            )
//            .foregroundStyle(
//                .secondary
//            )
//        }
//    }
//
//    private var searchResults: some View {
//        ScrollView(
//            showsIndicators: false
//        ) {
//            VStack(
//                alignment: .leading,
//                spacing: 24
//            ) {
//                if !folders.isEmpty {
//                    folderResultsSection
//                }
//
//                if !displayedFiles.isEmpty {
//                    fileResultsSection
//                }
//
//                if folders.isEmpty &&
//                    displayedFiles.isEmpty {
//
//                    noResultsView
//                }
//
//                Spacer()
//                    .frame(
//                        height: 30
//                    )
//            }
//            .padding(
//                .top,
//                20
//            )
//        }
//    }
//
//    private var folderResultsSection: some View {
//        VStack(
//            alignment: .leading,
//            spacing: 10
//        ) {
//            Text("Folders")
//                .font(
//                    .system(
//                        size: 19,
//                        weight: .medium
//                    )
//                )
//                .foregroundStyle(
//                    .black
//                )
//                .padding(
//                    .horizontal,
//                    20
//                )
//
//            VStack(spacing: 0) {
//                ForEach(
//                    Array(
//                        folders.enumerated()
//                    ),
//                    id: \.element.id
//                ) {
//                    index,
//                    folder in
//
//                    NavigationLink {
//                        DetailView(
//                            folder: folder,
//                            store: store
//                        )
//                    } label: {
//                        HStack(
//                            spacing: 16
//                        ) {
//                            miniFolder(
//                                folder
//                            )
//
//                            VStack(
//                                alignment: .leading,
//                                spacing: 3
//                            ) {
//                                Text(
//                                    folder.title
//                                )
//                                .font(
//                                    .system(
//                                        size: 16,
//                                        weight: .semibold
//                                    )
//                                )
//                                .foregroundStyle(
//                                    .black
//                                )
//
//                                Text(
//                                    "\(folder.itemCount) items"
//                                )
//                                .font(
//                                    .system(
//                                        size: 14,
//                                        weight: .medium
//                                    )
//                                )
//                                .foregroundStyle(
//                                    .secondary
//                                )
//                            }
//
//                            Spacer()
//
//                            Image(
//                                systemName:
//                                    "chevron.right"
//                            )
//                            .font(
//                                .system(
//                                    size: 14,
//                                    weight: .semibold
//                                )
//                            )
//                            .foregroundStyle(
//                                .black.opacity(
//                                    0.35
//                                )
//                            )
//                        }
//                        .padding(
//                            .horizontal,
//                            18
//                        )
//                        .frame(
//                            height: 82
//                        )
//                        .contentShape(
//                            Rectangle()
//                        )
//                    }
//                    .buttonStyle(
//                        .plain
//                    )
//
//                    if index !=
//                        folders.count - 1 {
//
//                        Divider()
//                            .opacity(
//                                0.25
//                            )
//                            .padding(
//                                .leading,
//                                92
//                            )
//                    }
//                }
//            }
//            .background {
//                RoundedRectangle(
//                    cornerRadius: 25,
//                    style: .continuous
//                )
//                .fill(
//                    .white.opacity(
//                        0.62
//                    )
//                )
//                .overlay {
//                    RoundedRectangle(
//                        cornerRadius: 25,
//                        style: .continuous
//                    )
//                    .strokeBorder(
//                        .white.opacity(
//                            0.95
//                        ),
//                        lineWidth: 1.2
//                    )
//                }
//                .shadow(
//                    color:
//                        .black.opacity(
//                            0.045
//                        ),
//                    radius: 8,
//                    y: 3
//                )
//            }
//            .padding(
//                .horizontal,
//                20
//            )
//        }
//    }
//
//    private var fileResultsSection: some View {
//        VStack(
//            alignment: .leading,
//            spacing: 10
//        ) {
//            Text("Files")
//                .font(
//                    .system(
//                        size: 19,
//                        weight: .medium
//                    )
//                )
//                .foregroundStyle(
//                    .black
//                )
//                .padding(
//                    .horizontal,
//                    20
//                )
//
//            VStack(spacing: 0) {
//                ForEach(
//                    Array(
//                        displayedFiles.enumerated()
//                    ),
//                    id: \.element.id
//                ) {
//                    index,
//                    result in
//
//                    Button {
//                        open(
//                            result.file
//                        )
//                    } label: {
//                        SearchFileRow(
//                            result: result
//                        )
//                    }
//                    .buttonStyle(
//                        .plain
//                    )
//
//                    if index !=
//                        displayedFiles.count - 1 {
//
//                        Divider()
//                            .opacity(
//                                0.25
//                            )
//                            .padding(
//                                .leading,
//                                70
//                            )
//                    }
//                }
//            }
//            .padding(
//                .vertical,
//                5
//            )
//            .background {
//                RoundedRectangle(
//                    cornerRadius: 25,
//                    style: .continuous
//                )
//                .fill(
//                    .white.opacity(
//                        0.62
//                    )
//                )
//                .overlay {
//                    RoundedRectangle(
//                        cornerRadius: 25,
//                        style: .continuous
//                    )
//                    .strokeBorder(
//                        .white.opacity(
//                            0.95
//                        ),
//                        lineWidth: 1.2
//                    )
//                }
//                .shadow(
//                    color:
//                        .black.opacity(
//                            0.045
//                        ),
//                    radius: 8,
//                    y: 3
//                )
//            }
//            .padding(
//                .horizontal,
//                20
//            )
//        }
//    }
//
//    private var noResultsView: some View {
//        VStack(spacing: 8) {
//            Image(
//                systemName:
//                    "magnifyingglass"
//            )
//            .font(
//                .system(
//                    size: 30
//                )
//            )
//            .foregroundStyle(
//                .secondary
//            )
//
//            Text("No Results")
//                .font(
//                    .system(
//                        size: 18,
//                        weight: .semibold
//                    )
//                )
//                .foregroundStyle(
//                    .black
//                )
//
//            Text(
//                "No files or folders match “\(trimmedSearch)”"
//            )
//            .font(
//                .system(
//                    size: 14
//                )
//            )
//            .foregroundStyle(
//                .secondary
//            )
//        }
//        .frame(
//            maxWidth: .infinity
//        )
//        .padding(
//            .top,
//            80
//        )
//    }
//
//    private func open(
//        _ file: DriveFile
//    ) {
//        store.recordOpened(
//            file
//        )
//
//        guard let url =
//            file.webURL
//        else {
//            return
//        }
//
//        openURL(url)
//    }
//
//    private func miniFolder(
//        _ folder: FolderCardModel
//    ) -> some View {
//        ZStack(
//            alignment: .topLeading
//        ) {
//            UnevenRoundedRectangle(
//                topLeadingRadius: 7,
//                bottomLeadingRadius: 8,
//                bottomTrailingRadius: 8,
//                topTrailingRadius: 7,
//                style: .continuous
//            )
//            .fill(
//                folder.topColor
//            )
//            .frame(
//                width: 30,
//                height: 18
//            )
//            .offset(
//                x: 2,
//                y: 1
//            )
//
//            RoundedRectangle(
//                cornerRadius: 8,
//                style: .continuous
//            )
//            .fill(
//                LinearGradient(
//                    colors: [
//                        folder.topColor,
//                        folder.bottomColor
//                    ],
//                    startPoint:
//                        .topLeading,
//                    endPoint:
//                        .bottomTrailing
//                )
//            )
//            .frame(
//                width: 61,
//                height: 44
//            )
//            .offset(
//                y: 9
//            )
//            .overlay {
//                RoundedRectangle(
//                    cornerRadius: 8,
//                    style: .continuous
//                )
//                .fill(
//                    LinearGradient(
//                        colors: [
//                            .white.opacity(
//                                0.22
//                            ),
//                            .clear
//                        ],
//                        startPoint:
//                            .top,
//                        endPoint:
//                            .bottom
//                    )
//                )
//                .frame(
//                    width: 61,
//                    height: 44
//                )
//                .offset(
//                    y: 9
//                )
//            }
//        }
//        .frame(
//            width: 61,
//            height: 53
//        )
//        .shadow(
//            color:
//                folder.bottomColor
//                    .opacity(
//                        0.18
//                    ),
//            radius: 5,
//            y: 3
//        )
//    }
//}
//
//struct SearchFileResult:
//    Identifiable {
//
//    let folder: FolderCardModel
//    let file: DriveFile
//
//    var id: String {
//        file.id
//    }
//}
//
//struct SearchFileRow: View {
//
//    let result: SearchFileResult
//
//    var body: some View {
//        HStack(
//            spacing: 13
//        ) {
//            ZStack {
//                RoundedRectangle(
//                    cornerRadius: 11,
//                    style: .continuous
//                )
//                .fill(
//                    .white.opacity(
//                        0.8
//                    )
//                )
//
//                RoundedRectangle(
//                    cornerRadius: 11,
//                    style: .continuous
//                )
//                .strokeBorder(
//                    .white.opacity(
//                        0.95
//                    ),
//                    lineWidth: 1
//                )
//
//                Image(
//                    systemName:
//                        result.file.icon
//                )
//                .font(
//                    .system(
//                        size: 18,
//                        weight: .semibold
//                    )
//                )
//                .foregroundStyle(
//                    result.file.color
//                )
//            }
//            .frame(
//                width: 45,
//                height: 45
//            )
//
//            VStack(
//                alignment: .leading,
//                spacing: 3
//            ) {
//                Text(
//                    result.file.name
//                )
//                .font(
//                    .system(
//                        size: 16,
//                        weight: .medium
//                    )
//                )
//                .foregroundStyle(
//                    .black
//                )
//                .lineLimit(1)
//
//                Text(
//                    "\(result.folder.title) · \(result.file.details)"
//                )
//                .font(
//                    .system(
//                        size: 13
//                    )
//                )
//                .foregroundStyle(
//                    .secondary
//                )
//                .lineLimit(1)
//            }
//
//            Spacer()
//
//            Image(
//                systemName:
//                    "arrow.up.forward"
//            )
//            .font(
//                .system(
//                    size: 12,
//                    weight: .semibold
//                )
//            )
//            .foregroundStyle(
//                .secondary
//            )
//        }
//        .padding(
//            .horizontal,
//            15
//        )
//        .frame(
//            height: 73
//        )
//        .contentShape(
//            Rectangle()
//        )
//    }
//}
//
//#Preview {
//    TabBar()
//}
