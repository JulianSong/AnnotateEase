//
//  WelcomView.swift
//  AnnotateEase
//
//  Created by julian on 2024/3/6.
//  Copyright © 2024 Julian.Song. All rights reserved.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack{
            VStack(alignment: .leading){
                Text("AnnotateEase")
                    .font(.largeTitle)
                Text("Easily and quickly label text data.")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "AnnotateEase://create")!)
                    self.dismiss()
                }, label: {
                    Label("Create a new project", systemImage: "doc.badge.plus")
                })
                .buttonStyle(.link)
                Button(action: {
                    self.openProject()
                }, label: {
                    Label("Open an existing project", systemImage: "doc")
                })
                .buttonStyle(.link)
                .padding(.bottom)
            }
            .fixedSize()
        }
        .padding()
        .frame(minWidth: 800,minHeight: 500, maxHeight: .infinity)
    }
    
    func openProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.annotateeaseProjectFile]
        if panel.runModal() == .OK, let url = panel.url {
            NSWorkspace.shared.open(url)
            self.dismiss()
        }
    }
}

#Preview {
    WelcomeView()
}
