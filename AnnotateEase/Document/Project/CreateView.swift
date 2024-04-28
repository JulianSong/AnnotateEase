//
//  AddView.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/12.
//

import SwiftUI

struct CreateView: View {
    @EnvironmentObject var editModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State var name:String = ""
    @State var fileURL: URL? = nil
    @State var filePath:String = ""
    @State private var error:LocalizedAlertError? = nil
    @State private var showAlert = false
    var body: some View {
        VStack(alignment: .leading,spacing: 0){
            Text("Create Porject")
                .padding()
            Spacer()
            VStack{
                Form {
                    TextField("Project Name", text: $name, prompt: Text("Name"))
                        .onChange(of: self.name) { oldValue, newValue in
                            guard let fileURL = self.fileURL else {
                                return
                            }
                            self.filePath = fileURL.appendingPathComponent(self.name).path
                        }
                    HStack{
                        TextField("Project Path", text: $filePath, prompt: Text("Project Path"))
                        Button {
                            self.openFile()
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
                .frame(minWidth: 300,idealWidth: 350, maxWidth: .infinity)
                .padding(.horizontal)
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
                Button() {
                    self.create()
                } label: {
                    Text("Create")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .selectedContentBackgroundColor))
                .disabled(self.name.isEmpty || self.filePath.isEmpty)
            }
            .padding()
        }
        .frame(height: 300)
        .frame(minWidth: 500, maxWidth: 600)
        .alert(isPresented: $showAlert, error: error) { _ in
            Button("OK") {
                self.showAlert.toggle()
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try again later.")
        }
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
            self.fileURL = url
            if self.name.isEmpty {
                self.filePath = url.path()
            }else{
                self.filePath = url.appendingPathComponent(self.name).path
            }
        }
    }
    
    func create() {
        let project = Project(projectName: self.name)
        let url = self.fileURL!.appending(path: self.name)
        let projectFileUrl = url.appending(path: "\(self.name).aegr")
        let projectTextsFolder = projectFileUrl.appending(path: "Texts")
        Task{
            do{
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: projectFileUrl, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: projectTextsFolder, withIntermediateDirectories: true)
                self.editModel.prjectFilePath = projectFileUrl
                self.editModel.projectPath = url
                self.editModel.project = project
                try await self.editModel.saveProject()
                self.dismiss()
            }catch{
                self.error = LocalizedAlertError(error: error)
                self.showAlert.toggle()
            }
        }
    }
}
