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
    @State var recent: [URL] = []
    var body: some View {
        VStack{
            HStack{
                VStack(alignment: .center){
                    Image("AnnotateEase", bundle: .main)
                        .padding(.bottom,30)
                        .shadow(color: Color.black.opacity(0.2), radius: 30,x: 8,y: 14)
                    VStack(alignment: .leading){
                        Text("Easily and quickly label text data.")
                            .font(.title)
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
                }
                .fixedSize()
                .padding(100)
                List{
                    ForEach(self.recent,id: \.self.path){ url in
                        VStack(alignment: .leading){
                            Button(action: {
                                if url.startAccessingSecurityScopedResource() {
                                    NSWorkspace.shared.open(url)
                                }
                            }, label: {
                                Text(url.lastPathComponent)
                                    .multilineTextAlignment(.leading)
                            })
                            .buttonStyle(.link)
                            Text(url.path)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity,alignment:.init(horizontal: .leading, vertical: .center))
                        .listRowSeparator(.hidden)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
                .ignoresSafeArea()
                .frame(width: 300)
            }
        }
        .frame(height: 500)
        .onAppear{
            self.loadRecent()
        }
    }
    
    func loadRecent() {
        guard let recent:[String] = UserDefaults.standard.array(forKey: "studio.peachtree.annotateease.recent") as? [String] else {
            return
        }
        self.recent = recent.reversed().compactMap{ URL(fileURLWithPath: $0) }
    }
    
    func openProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.annotateeaseProjectFile]
        if panel.runModal() == .OK, let url = panel.url {
            NSWorkspace.shared.open(url)
            var recent:[String] = UserDefaults.standard.array(forKey: "studio.peachtree.annotateease.recent") as? [String] ?? [String]()
            recent.removeAll { $0 == url.path }
            recent.append(url.path)
            UserDefaults.standard.set(recent, forKey: "studio.peachtree.annotateease.recent")
            self.dismiss()
        }
    }
}

#Preview {
    WelcomeView()
}
