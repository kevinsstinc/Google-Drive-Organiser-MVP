//
//  LaunchFlowView.swift
//  documents
//

import SwiftUI
import GoogleSignIn
import UIKit

private let googleDriveMetadataScope =
    "https://www.googleapis.com/auth/drive.readonly"

private enum LaunchStage {
    case restoring
    case onboarding
    case signIn
    case folderSelection
    case app
}

struct LaunchFlowView: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @AppStorage("launch.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    @State private var stage: LaunchStage = .restoring
    @State private var selectedPage = 0
    @State private var didAttemptSessionRestore = false
    @State private var isSigningIn = false
    @State private var signInError: String?

    var body: some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            switch stage {
            case .restoring:
                ProgressView()
                    .controlSize(.large)
                    .tint(AppPalette.accent)
                    .accessibilityLabel("Restoring your session")

            case .onboarding:
                OnboardingDraftView(
                    selectedPage: $selectedPage,
                    onFinish: showSignIn
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading)
                            .combined(with: .opacity)
                    )
                )

            case .signIn:
                SignInDraftView(
                    onBack: showOnboarding,
                    onGoogleSignIn: signInWithGoogle,
                    onDeveloperMode: enterDeveloperMode,
                    isSigningIn: isSigningIn,
                    errorMessage: signInError
                )
                .transition(
                    .move(edge: .trailing)
                        .combined(with: .opacity)
                )

            case .folderSelection:
                NavigationStack {
                    FolderSelectionView(
                        purpose: .onboarding,
                        onSave: { _ in
                            showApp()
                        },
                        onCancel: signOut
                    )
                }
                .transition(.opacity)

            case .app:
                TabBar(onSignOut: signOut)
                    .transition(.opacity)
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .snappy(duration: 0.34),
            value: stage
        )
        .onAppear {
            restoreSessionIfNeeded()
        }
    }

    private func showSignIn() {
        hasCompletedOnboarding = true
        signInError = nil
        stage = .signIn
    }

    private func showOnboarding() {
        selectedPage = 0
        signInError = nil
        stage = .onboarding
    }

    private func showApp() {
        signInError = nil
        stage = .app
    }

    private func showAuthenticatedDestination() {
        signInError = nil
        stage = FolderSelectionStore.hasSelection
            ? .app
            : .folderSelection
    }

    private func enterDeveloperMode() {
        GIDSignIn.sharedInstance.signOut()
        showAuthenticatedDestination()
    }

    private func restoreSessionIfNeeded() {
        guard !didAttemptSessionRestore else {
            return
        }

        didAttemptSessionRestore = true

        GIDSignIn.sharedInstance.restorePreviousSignIn {
            user,
            _ in

            guard let user else {
                DispatchQueue.main.async {
                    stage = hasCompletedOnboarding
                        ? .signIn
                        : .onboarding
                }
                return
            }

            user.refreshTokensIfNeeded { refreshedUser, error in
                DispatchQueue.main.async {
                    guard let refreshedUser else {
                        stage = .signIn
                        signInError = error?.localizedDescription
                            ?? "Sign in again to connect Google Drive."
                        return
                    }

                    guard hasDriveMetadataAccess(refreshedUser) else {
                        stage = .signIn
                        signInError =
                            "Allow Drive access to organise your files."
                        return
                    }

                    finishGoogleAuthorization(refreshedUser)
                }
            }
        }
    }

    private func signInWithGoogle() {
        guard !isSigningIn else {
            return
        }

        guard let presenter =
            UIApplication.shared.activeViewController
        else {
            signInError = "Google Sign-In is unavailable right now."
            return
        }

        isSigningIn = true
        signInError = nil

        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            authorizeDrive(
                for: currentUser,
                presenting: presenter
            )
            return
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presenter,
            hint: nil,
            additionalScopes: [googleDriveMetadataScope]
        ) { result, error in
            DispatchQueue.main.async {
                isSigningIn = false

                guard let user = result?.user else {
                    if let error,
                       (error as NSError).code
                        != GIDSignInError.canceled.rawValue {
                        signInError = error.localizedDescription
                    }
                    return
                }

                guard hasDriveMetadataAccess(user) else {
                    signInError =
                        "Allow Drive access to organise your files."
                    return
                }

                finishGoogleAuthorization(user)
            }
        }
    }

    private func authorizeDrive(
        for user: GIDGoogleUser,
        presenting presenter: UIViewController
    ) {
        guard !hasDriveMetadataAccess(user) else {
            user.refreshTokensIfNeeded { refreshedUser, error in
                DispatchQueue.main.async {
                    isSigningIn = false

                    guard let refreshedUser else {
                        signInError = error?.localizedDescription
                            ?? "Sign in again to connect Google Drive."
                        return
                    }

                    guard hasDriveMetadataAccess(refreshedUser) else {
                        signInError =
                            "Allow Drive access to organise your files."
                        return
                    }

                    finishGoogleAuthorization(refreshedUser)
                }
            }
            return
        }

        user.addScopes(
            [googleDriveMetadataScope],
            presenting: presenter
        ) { result, error in
            DispatchQueue.main.async {
                isSigningIn = false

                guard let authorizedUser = result?.user else {
                    if let error,
                       (error as NSError).code
                        != GIDSignInError.canceled.rawValue {
                        signInError = error.localizedDescription
                    }
                    return
                }

                guard hasDriveMetadataAccess(authorizedUser) else {
                    signInError =
                        "Allow Drive access to organise your files."
                    return
                }

                finishGoogleAuthorization(authorizedUser)
            }
        }
    }

    private func hasDriveMetadataAccess(
        _ user: GIDGoogleUser
    ) -> Bool {
        user.grantedScopes?.contains(
            googleDriveMetadataScope
        ) == true
    }

    private func finishGoogleAuthorization(
        _ user: GIDGoogleUser
    ) {
        saveProfileName(from: user)
        showAuthenticatedDestination()
    }

    private func saveProfileName(
        from user: GIDGoogleUser
    ) {
        guard let name =
            user.profile?.givenName
            ?? user.profile?.name,
              !name.isEmpty
        else {
            return
        }

        UserDefaults.standard.set(
            name,
            forKey: AppProfile.displayNameKey
        )
    }

    private func signOut() {
        GIDSignIn.sharedInstance.signOut()
        UserDefaults.standard.removeObject(
            forKey: AppProfile.displayNameKey
        )
        FolderSelectionStore.clear()
        hasCompletedOnboarding = true
        selectedPage = 0
        isSigningIn = false
        signInError = nil
        stage = .signIn
    }
}

private extension UIApplication {
    var activeViewController: UIViewController? {
        let activeScene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var controller = activeScene?
            .windows
            .first(where: \.isKeyWindow)?
            .rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }

        return controller
    }
}

private struct OnboardingPage: Identifiable {
    enum Artwork {
        case folders
        case search
    }

    let id: Int
    let eyebrow: String
    let title: String
    let message: String
    let artwork: Artwork

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            eyebrow: "SMART FOLDERS",
            title: "Everything,\nin its place.",
            message: "Turn Drive into simple Smart Folders.",
            artwork: .folders
        ),
        OnboardingPage(
            id: 1,
            eyebrow: "FIND IT FAST",
            title: "Find any file\nfast.",
            message: "Search every folder in one place.",
            artwork: .search
        )
    ]
}

private struct OnboardingDraftView: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Binding var selectedPage: Int
    let onFinish: () -> Void

    private let pages = OnboardingPage.pages

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $selectedPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(
                .page(indexDisplayMode: .never)
            )

            footer
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var header: some View {
        HStack {
            Label {
                Text("Documents")
                    .font(.headline)
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(AppPalette.accent)
            }

            Spacer()
        }
    }

    private var footer: some View {
        VStack(spacing: 18) {
            PageIndicator(
                pageCount: pages.count,
                selectedPage: selectedPage
            )

            Button {
                advance()
            } label: {
                HStack(spacing: 8) {
                    Text(
                        selectedPage == pages.count - 1
                            ? "Sign in"
                            : "Continue"
                    )

                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(AppPalette.accent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                selectedPage == pages.count - 1
                    ? "Opens sign in"
                    : "Shows the next introduction page"
            )
        }
    }

    private func advance() {
        guard selectedPage < pages.count - 1 else {
            onFinish()
            return
        }

        withAnimation(
            reduceMotion
                ? nil
                : .snappy(duration: 0.3)
        ) {
            selectedPage += 1
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                artwork
                    .frame(height: 300)

                VStack(spacing: 13) {
                    Text(page.eyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(AppPalette.accent)

                    Text(page.title)
                        .font(
                            .system(
                                .largeTitle,
                                design: .rounded,
                                weight: .bold
                            )
                        )
                        .tracking(-0.8)
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 430)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var artwork: some View {
        switch page.artwork {
        case .folders:
            OnboardingFolderArtwork()
        case .search:
            OnboardingSearchArtwork()
        }
    }
}

private struct PageIndicator: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let pageCount: Int
    let selectedPage: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        index == selectedPage
                            ? AppPalette.accent
                            : Color.secondary.opacity(0.22)
                    )
                    .frame(
                        width: index == selectedPage ? 24 : 7,
                        height: 7
                    )
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .snappy(duration: 0.24),
            value: selectedPage
        )
        .accessibilityElement()
        .accessibilityLabel(
            "Page \(selectedPage + 1) of \(pageCount)"
        )
    }
}

private struct OnboardingFolderArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.52))
                .frame(width: 280, height: 280)
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.78),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: AppPalette.accent.opacity(0.10),
                    radius: 34,
                    y: 16
                )

            GlassFolderView(
                folder: .constant(
                    FolderCardModel.samples[2]
                ),
                showsMenuButton: false
            )
            .frame(width: 150, height: 150)
            .rotationEffect(.degrees(-7))
            .offset(x: -76, y: -35)
            .opacity(0.88)

            GlassFolderView(
                folder: .constant(
                    FolderCardModel.samples[1]
                ),
                showsMenuButton: false
            )
            .frame(width: 150, height: 150)
            .rotationEffect(.degrees(7))
            .offset(x: 76, y: -35)
            .opacity(0.92)

            GlassFolderView(
                folder: .constant(
                    FolderCardModel.samples[0]
                ),
                showsMenuButton: false
            )
            .frame(width: 198, height: 198)
            .rotationEffect(.degrees(-2))
            .offset(y: 48)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Colourful Smart Folders organising documents"
        )
    }
}

private struct OnboardingSearchArtwork: View {
    private let results: [SearchPreview] = [
        SearchPreview(
            symbol: "doc.text.fill",
            color: AppPalette.softBlue,
            title: "Biology Notes.pdf",
            detail: "School"
        ),
        SearchPreview(
            symbol: "rectangle.stack.fill",
            color: AppPalette.softOrange,
            title: "Project Proposal.key",
            detail: "Projects"
        ),
        SearchPreview(
            symbol: "airplane",
            color: AppPalette.softGreen,
            title: "Travel Itinerary.pdf",
            detail: "Personal"
        )
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(AppPalette.accent)

                Text("Search your documents")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.82))
            }

            VStack(spacing: 0) {
                ForEach(results) { result in
                    SearchPreviewRow(result: result)

                    if result.id != results.last?.id {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
            .background {
                RoundedRectangle(
                    cornerRadius: 23,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.72))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 23,
                        style: .continuous
                    )
                    .strokeBorder(
                        Color.white.opacity(0.86),
                        lineWidth: 1
                    )
                }
            }
        }
        .padding(15)
        .frame(maxWidth: 390)
        .background {
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .fill(AppPalette.accent.opacity(0.08))
        }
        .shadow(
            color: AppPalette.accent.opacity(0.10),
            radius: 28,
            y: 14
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Search showing Biology Notes, Project Proposal, and Travel Itinerary"
        )
    }
}

private struct SearchPreview: Identifiable {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var id: String { title }
}

private struct SearchPreviewRow: View {
    let result: SearchPreview

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(
                cornerRadius: 11,
                style: .continuous
            )
            .fill(result.color.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: result.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(result.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(result.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 13)
        .frame(height: 63)
    }
}

private struct SignInDraftView: View {
    let onBack: () -> Void
    let onGoogleSignIn: () -> Void
    let onDeveloperMode: () -> Void
    let isSigningIn: Bool
    let errorMessage: String?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    Spacer(minLength: 24)

                    GlassFolderView(
                        folder: .constant(
                            FolderCardModel.samples[0]
                        ),
                        showsMenuButton: false
                    )
                    .frame(width: 210, height: 210)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("School Smart Folder")

                    VStack(spacing: 13) {
                        Text("Connect your Drive.")
                            .font(
                                .system(
                                    .largeTitle,
                                    design: .rounded,
                                    weight: .bold
                                )
                            )
                            .tracking(-0.8)
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)

                        Text(
                            "Organise and find files in one place."
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 420)
                    }

                    VStack(spacing: 12) {
                        Button(action: onGoogleSignIn) {
                            HStack(spacing: 12) {
                                if isSigningIn {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.black)
                                        .frame(width: 22, height: 22)
                                } else {
                                    Image("Google")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .accessibilityHidden(true)
                                }

                                Text(
                                    isSigningIn
                                        ? "Signing in…"
                                        : "Continue with Google"
                                )
                                .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                            .background {
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                                .fill(Color.white.opacity(0.9))
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .strokeBorder(
                                        Color.black.opacity(0.08),
                                        lineWidth: 1
                                    )
                                }
                                .shadow(
                                    color: .black.opacity(0.045),
                                    radius: 7,
                                    y: 3
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSigningIn)
                        .accessibilityLabel(
                            isSigningIn
                                ? "Signing in with Google"
                                : "Continue with Google"
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 360)
                        }

#if DEBUG
                        Button(action: onDeveloperMode) {
                            Text("Developer Mode")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppPalette.accent)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background {
                                    RoundedRectangle(
                                        cornerRadius: 14,
                                        style: .continuous
                                    )
                                    .fill(Color.white.opacity(0.68))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            "Opens the app without signing in"
                        )
#endif

                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(AppPalette.accent)

                            Text(
                                "Secure Google Sign-In"
                            )
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 26)

                    Spacer(minLength: 28)

                    Text(
                        "By continuing, you agree to the Terms and Privacy Policy."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                }
                .frame(
                    maxWidth: 520,
                    minHeight: proxy.size.height
                )
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var header: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.62))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to introduction")

            Spacer()

            Text("Documents")
                .font(.headline)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Onboarding") {
    LaunchFlowView()
}

#Preview("Sign In") {
    SignInDraftView(
        onBack: { },
        onGoogleSignIn: { },
        onDeveloperMode: { },
        isSigningIn: false,
        errorMessage: nil
    )
    .background {
        AppPalette.background
            .ignoresSafeArea()
    }
}
