//
//  documentsApp.swift
//  documents
//
//  Created by Joseph Kevin Fredric on 16/8/26.
//
import SwiftUI
import GoogleSignIn
import FirebaseCore
import FirebaseAppCheck
import FirebaseAILogic

@main
struct documentsApp: App {
    init() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(
            AppCheckDebugProviderFactory()
        )
        #else
        AppCheck.setAppCheckProviderFactory(
            AppAttestProviderFactory()
        )
        #endif

        if FirebaseOptions.defaultOptions() != nil {
            FirebaseApp.configure()

            print("🔥 FIREBASE CONFIGURED")
            print(
                "🔥 PROJECT:",
                FirebaseApp.app()?.options.projectID ?? "NO PROJECT"
            )
        } else {
            print("❌ GoogleService-Info.plist NOT FOUND")
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchFlowView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await testGemini()
                }
        }
    }

    private func testGemini() async {
        guard FirebaseApp.app() != nil else {
            print("❌ Gemini skipped because Firebase isn't configured")
            return
        }

        do {
            let ai = FirebaseAI.firebaseAI(
                backend: .googleAI()
            )

            let model = ai.generativeModel(
                modelName: "gemini-3.6-flash"
            )

            let response = try await model.generateContent(
                "Reply with exactly: GEMINI WORKS"
            )

            print(
                "✅ GEMINI:",
                response.text ?? "NO RESPONSE"
            )
        } catch {
            print("❌ GEMINI ERROR:")
            print(error)
        }
    }
}
