//
//  DataTaggerApp.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/11.
//

import SwiftUI

@main
struct DataTaggerApp: App {
    var body: some Scene {
        WindowGroup{
            WelcomeView()
        }
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: [])
        
        WindowGroup {
            HomeView()
                .frame(minWidth: 1100,maxWidth: .infinity, minHeight: 600,maxHeight: .infinity)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "create"), allowing: Set(arrayLiteral: "create"))
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
//        .handlesExternalEvents(matching: ["create","file"])
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button {
                    if let url = URL(string: "AnnotateEase://create") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Creat a new project")
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
            CommandGroup(after: .newItem) {
                Button {
                    self.openProject()
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
    
    func openProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.annotateeaseProjectFile]
        if panel.runModal() == .OK, let url = panel.url {
            NSWorkspace.shared.open(url)
        }
    }
}
