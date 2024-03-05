//
//  AddView.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/12.
//

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
   @Binding
   var window: NSWindow?
   func makeNSView(context: Context) -> NSView {
      let view = NSView()
      DispatchQueue.main.async {
         self.window = view.window
      }
      return view
   }
   func updateNSView(_ nsView: NSView, context: Context) {}
}

struct CreateView: View {
    @EnvironmentObject var editModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State var name:String = ""
    @State var filePath:String = ""
    var body: some View {
        VStack(alignment: .leading,spacing: 0){
            Text("Create Porject")
                .padding()
            Spacer()
            VStack{
                Form {
                    TextField("Name", text: $name, prompt: Text("Name"))
                    HStack{
                        TextField("Saved Path", text: $filePath, prompt: Text("Json File Saved Path"))
                        Button {
                            self.openFile()
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
                .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity,maxHeight:.infinity)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.gray, lineWidth: 0.5)
            )
            .padding(.horizontal)
            
            Spacer()
            HStack{
                Button {
                    self.dismiss()
                } label: {
                    Text("Cancel")
                }
                .accentColor(Color(nsColor: .controlAccentColor))
                Spacer()
                Button {
                    self.create()
                } label: {
                    Text("Create")
                }
                .accentColor(Color(nsColor: .controlAccentColor))
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .onDisappear {
            if self.editModel.project == nil {
                NSApplication.shared.keyWindow?.close()
            }
        }
    }
    
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowedContentTypes = [.annotateeaseProjectFile]
        if panel.runModal() == .OK, let url = panel.url {
            self.filePath = url.path()
        }
    }
    
    func create() {
        let project = Project(projectName: self.name)
        let url = URL(filePath: self.filePath).appending(path: self.name)
        let projectFileUrl = url.appending(path: "\(self.name).aegr")
        let projectTextsFolder = projectFileUrl.appending(path: "Texts")
        do{
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: projectFileUrl, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: projectTextsFolder, withIntermediateDirectories: true)
            self.editModel.prjectFilePath = projectFileUrl
            self.editModel.projectPath = url
            self.editModel.project = project
            try self.editModel.saveProject()
            self.dismiss()
        }catch{
            
        }
    }
}
