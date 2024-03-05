//
//  CreateDatasetView.swift
//  AnnotateEase
//
//  Created by julian on 2024/3/5.
//  Copyright © 2024 Julian.Song. All rights reserved.
//

import SwiftUI

struct CreateDatasetView: View {
    @EnvironmentObject var editModel: HomeViewModel
    @Environment(\.presentationMode) var presentationMode
    @State var name:String = ""
    @State var filePath:String = ""
    var body: some View {
        VStack(alignment: .leading,spacing: 0){
            Text("Create Dataset")
                .padding()
            Spacer()
            VStack{
                Form {
                    TextField("Name", text: $name, prompt: Text("Name"))
//                    TextField("Saved Path", text: $filePath, prompt: Text("Json File Saved Path"))
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
                    self.presentationMode.wrappedValue.dismiss()
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
    }
    
    func create() {
        let dataset = Project.Dataset(title: self.name, type: "text_word_tag", file: "\(self.name).json", labels: [])
        do {
            self.editModel.project?.datasets.append(dataset)
            try self.editModel.saveProject()
            self.editModel.currentDataset = dataset
            self.presentationMode.wrappedValue.dismiss()
        } catch {
            
        }
    }
}