//
//  DatasetInspectorView.swift
//  AnnotateEase
//
//  Created by julian on 2024/5/1.
//  Copyright © 2024 Julian.Song. All rights reserved.
//

import SwiftUI

struct DatasetInspector: View {
    @ObservedObject var viewModel: HomeViewModel
    var body: some View {
        VStack{
            VStack(alignment: .leading) {
                HStack {
                    Text("Labels")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        self.viewModel.labels.append(LabelViewModel(label: .empty()))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .disabled(self.viewModel.project == nil)
                }
                .frame(height: 20)
                Table(of: LabelViewModel.self) {
                    TableColumn("Label") { label in
                        LabelsLabelColumn(viewModel:label)
                            .environmentObject(self.viewModel)
                    }
                    TableColumn("Title") { label in
                        LabelsTitleColumn(viewModel:label)
                            .environmentObject(self.viewModel)
                    }
                } rows: {
                    ForEach(self.viewModel.labels) { data in
                        TableRow(data)
                    }
                }
                Spacer()
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
        }
        .padding(0)
        .frame(minWidth:250,maxWidth: .infinity, maxHeight: .infinity)
        .transition(AnyTransition.move(edge: .trailing))
    }
}
