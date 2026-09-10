import FirebaseAppCheck
import FirebaseCore
import GoogleSignIn
//
//  documentsApp.swift
//  documents
//
//  Created by Joseph Kevin Fredric on 16/8/26.
//
import SwiftUI

@main
struct documentsApp: App {
  init() {
    #if targetEnvironment(simulator)
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
    }
  }

  var body: some Scene {
    WindowGroup {
      LaunchFlowView()
        .onOpenURL { url in
          GIDSignIn.sharedInstance.handle(url)
        }
    }
  }
}
