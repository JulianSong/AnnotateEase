//
//  DatasetView.swift
//  AnnotateEase
//
//  Created by julian on 2024/5/1.
//  Copyright © 2024 Julian.Song. All rights reserved.
//

import SwiftUI
import WrappingStack

class DataTagPairModel: ObservableObject, Identifiable {
    let id: String = UUID().uuidString
    @Published var lexical: [(String, Range<String.Index>)] = []
    @Published var label: String = ""
    @Published var showActions = false
    var token: String {
        return self.lexical.map{ $0.0 }.joined(separator: " ")
    }
    var pair: DataTagPair {
        return DataTagPair(token: self.token, label: self.label)
    }
}

class LabelViewModel: ObservableObject, Identifiable {
    var label:Project.Dataset.Label {
        return .init(label: self.labelText, title: self.title)
    }
    var id: String
    @Published var labelText: String = ""
    @Published var title: String = ""
    @Published var showActions = false
    init(label: Project.Dataset.Label) {
        self.id = label.id
        self.labelText = label.label
        self.title = label.title
    }
}

class DatasetViewModel: ObservableObject, Identifiable {
    @Published var labels: [LabelViewModel] = []
}

struct NewPairTokenColumn: View {
    @ObservedObject var viewModel: DataTagPairModel
    var body: some View {
        Text(viewModel.token)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onHover { _ in
                self.viewModel.showActions.toggle()
            }
    }
}

struct NewPairLabelColumn: View {
    @ObservedObject var editModel: HomeViewModel
    @ObservedObject var viewModel: DataTagPairModel
    var body: some View {
        HStack {
            Picker(selection: $viewModel.label) {
                ForEach(self.editModel.labels) { label in
                    Text(label.title)
                        .tag(label.labelText)
                }
                Text("none").tag("none")
            } label: {
                
            }
            .fixedSize()
            Spacer()
            Button {
                self.editModel.removePari(pari: self.viewModel)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .opacity(self.viewModel.showActions ? 1 : 0)
        }
        .onHover { _ in
            self.viewModel.showActions.toggle()
        }
    }
}

struct LabelsLabelColumn: View {
    @EnvironmentObject var editModel: HomeViewModel
    @ObservedObject var viewModel:LabelViewModel
    @FocusState private var isFocused: Bool
    var body: some View {
        HStack{
            TextField(text: $viewModel.labelText,prompt: Text("Label")) {
                EmptyView()
            }
            .focused($isFocused)
            .onChange(of: isFocused,initial: false) { _,_ in
                guard !self.isFocused && !viewModel.labelText.isEmpty && !viewModel.title.isEmpty else { return }
                Task{
                    try? await self.editModel.saveLabels()
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .onHover { _ in
            self.viewModel.showActions.toggle()
        }
    }
}

struct LabelsTitleColumn: View {
    @ObservedObject var viewModel:LabelViewModel
    @EnvironmentObject var editModel: HomeViewModel
    @FocusState private var isFocused: Bool
    var body: some View {
        HStack{
            TextField(text: $viewModel.title,prompt: Text("Title")) {
                EmptyView()
            }
            .focused($isFocused)
            .onChange(of: isFocused,initial: false) { _,_ in
                guard !self.isFocused && !viewModel.labelText.isEmpty && !viewModel.title.isEmpty else { return }
                Task{
                    try? await self.editModel.saveLabels()
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
            Button {
                self.editModel.labels.removeAll(where: { $0.id == viewModel.id })
                Task{
                    try? await self.editModel.saveLabels()
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .opacity(self.viewModel.showActions ? 1 : 0)
        }
        .onHover { _ in
            self.viewModel.showActions.toggle()
        }
    }
}

struct DatasetView: View {
    @ObservedObject var viewModel: HomeViewModel
    var dataList: some View {
        VStack(spacing: 0) {
            HStack {}
            Table(of: DataTagWrapper.self) {
                TableColumn("Token/Labels") { dataTag in
                    HStack {
                        ForEach(dataTag.tag.pairs) { pair in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pair.token)
                                    .padding(4)
                                    .font(.system(size: 14, weight: .bold))
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(4)
                                Text(pair.label)
                                    .padding(.leading, 4)
                                    .font(.system(size: 10))
                            }
                            .padding(2)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    .fixedSize()
                    .contextMenu{
                        Button(action: {
                            self.viewModel.removeData(data: dataTag)
                        }, label: {
                            Text("Delete")
                        })
                    }
                }
            } rows: {
                ForEach(self.viewModel.datas.reversed()) { data in
                    TableRow(data)
                }
            }
            Divider()
            HStack {
                Text("Total: \(self.viewModel.datas.count)")
                Spacer()
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
        }
        .frame(minWidth: 400, maxHeight: .infinity)
    }

    var textContent: some View {
        VStack {
            HStack {
                Text("Text")
                    .foregroundColor(.secondary)
                Spacer()
                if self.viewModel.mutilineMode {
                    Picker("", selection: $viewModel.textShowMode) {
                        ForEach(Project.Dataset.TextShowMode.allCases,id:\.rawValue) {
                            Text($0.rawValue)
                                .tag($0)
                        }
                      }
                      .pickerStyle(.segmented)
                      .fixedSize()
                    Spacer()
                }
                Toggle(isOn: self.$viewModel.mutilineMode) {
                    Text("Mutiline Mode")
                }
            }
            .frame(height: 20)
            VStack {
                if self.viewModel.textShowMode == .text || !self.viewModel.mutilineMode {
                    TextEditor(text: $viewModel.text)
//                        .padding(.leading,25)
                        .padding(.top,2)
                        .background(Color.clear)
                        .font(.body)
                        .lineSpacing(4.5)
                        .textSelection(.enabled)
                        .selectionDisabled(false)
                }else{
                    ScrollViewReader{ proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0){
                                ForEach(Array(self.viewModel.sentences.enumerated()),id:\.offset) { index,sentence in
                                    HStack(alignment: .firstTextBaseline){
                                        Text("\(index + 1)")
                                            .font(.footnote)
                                            .foregroundColor(Color.secondary)
                                            .frame(minWidth: 20,alignment: .trailing)
                                        Text(sentence)
                                            .font(.body)
                                            .multilineTextAlignment(.leading)
                                            .padding(2)
                                            .frame(maxWidth: .infinity,alignment: .leading)
                                            .lineSpacing(4)
                                    }
                                    .background(self.viewModel.selectedSentenceIndex == index ? Color.primary.opacity(0.1) : Color.clear )
                                    .frame(maxWidth: .infinity,alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.viewModel.selectedSentenceIndex = index
                                    }
                                    .contextMenu {
                                        Button {
                                            NSPasteboard.general.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                                            NSPasteboard.general.setString(sentence, forType: .string)
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                    }
                                    .id(index)
                                }
                            }
                        }
                        .onAppear{
                            proxy.scrollTo(self.viewModel.selectedSentenceIndex)
                        }
                        .onChange(of: self.viewModel.selectedSentenceIndex) { oldValue, newValue in
                            proxy.scrollTo(newValue)
                        }
                    }
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity, minHeight: 100, maxHeight: self.viewModel.mutilineMode ? .infinity : 140)
            .padding(4)
            .background(Color(.controlBackgroundColor))          }
    }

    var mutilineTextContent: some View {
        VStack(spacing: 0) {
            textContent
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                .frame(maxHeight: .infinity)
            Divider()
            HStack {
                Text("Sentence: \(self.viewModel.sentences.count)")
                Spacer()
                Button {
                    guard
                        let index = self.viewModel.selectedSentenceIndex,
                        (index - 1) >= self.viewModel.sentences.startIndex
                    else { return }
                    self.viewModel.selectedSentenceIndex = index - 1
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.upArrow,modifiers: [.command])
                Text("\((self.viewModel.selectedSentenceIndex ?? -1) + 1)")
                Button {
                    guard
                        let index = self.viewModel.selectedSentenceIndex,
                        (index + 1) < self.viewModel.sentences.endIndex
                    else { return }
                    self.viewModel.selectedSentenceIndex = index + 1
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.downArrow,modifiers: [.command])
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
        }
    }
    
    var editor: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                if !viewModel.mutilineMode {
                    textContent
                }
                Text("Lexical")
                    .foregroundColor(.secondary)
                    .frame(height: 20)
                ScrollView{
                    VStack {
                        WrappingHStack(id: \.self,
                                       alignment: .topLeading,
                                       horizontalSpacing: 4,
                                       verticalSpacing: 4) {
                            ForEach(viewModel.lexical.indices, id: \.self) { index in
                                Text(viewModel.lexical[index].0)
                                    .padding(2)
                                    .padding(.horizontal, 4)
                                    .foregroundColor(self.viewModel.usedLexical.contains(where: { $0.1 == viewModel.lexical[index].1 }) ? .secondary : .primary)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        self.viewModel.add(lexical: viewModel.lexical[index])
                                    }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(4)
                .frame(minHeight: 100, maxHeight: 140)
                .background(Color(.controlBackgroundColor))
                HStack {
                    Text("Token/Labels")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        self.viewModel.clearParis()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 20)
                Table(of: DataTagPairModel.self) {
                    TableColumn("Token") { pari in
                        NewPairTokenColumn(viewModel: pari)
                    }
                    TableColumn("Label") { pari in
                        NewPairLabelColumn(editModel: viewModel, viewModel: pari)
                    }
                } rows: {
                    ForEach(self.viewModel.pairs) { data in
                        TableRow(data)
                    }
                }
                Spacer()
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button {
                    Task{
                       await self.viewModel.save()
                    }
                } label: {
                    Text("Save")
                }
                .disabled(self.viewModel.project == nil)
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
        }
        .padding(0)
        .frame(minWidth: 400, maxHeight: .infinity)
    }

    var body: some View {
        HSplitView {
            dataList
            if viewModel.mutilineMode {
                mutilineTextContent
            }
            editor
        }
        .navigationTitle(self.viewModel.project?.projectName ?? "")
    }
}
