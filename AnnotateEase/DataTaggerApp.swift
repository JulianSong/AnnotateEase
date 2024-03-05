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
        WindowGroup("", id: "new_window") {
            HomeView()
                .frame(minWidth: 1100,maxWidth: .infinity, minHeight: 600,maxHeight: .infinity)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
                .handlesExternalEvents(preferring: Set(arrayLiteral: "create"), allowing: Set(arrayLiteral: "create"))
        }
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
