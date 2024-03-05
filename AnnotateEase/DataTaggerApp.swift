//
//  DataTaggerApp.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/11.
//

import SwiftUI

@main
struct DataTaggerApp: App {
    @StateObject var viewModel = HomeViewModel()
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100,maxWidth: .infinity, minHeight: 600,maxHeight: .infinity)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button {} label: {
                    Text("Creat a new project")
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
            CommandGroup(after: .newItem) {
                Button {
                    self.viewModel.openProject()
                } label: {
                    Text("Open an existing project")
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .toolbar) {}
        }
    }
}
