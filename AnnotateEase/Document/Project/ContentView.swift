//
//  ContentView.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/11.
//

import NaturalLanguage
import SwiftUI
import UniformTypeIdentifiers
import WrappingStack


class DataTagPairModel: ObservableObject, Identifiable {
    let id: String = UUID().uuidString
    @Published var lexical: [String] = []
    @Published var label: String = ""
    @Published var showActions = false
    var token: String {
        return self.lexical.joined(separator: " ")
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

class HomeViewModel: ObservableObject {
    static let tags: Set<NLTag> = [.whitespace, .paragraphBreak]
    var prjectFilePath: URL?
    var projectPath: URL?
    @Published var sideBarSelection:String?
    @Published var project: Project?
    @Published var mutilineMode = false {
        didSet {
            self.project?.mutilineMode = self.mutilineMode
            try? self.saveProject()
        }
    }

    @Published var currentDataset: Project.Dataset? {
        didSet {
            self.project?.currentDataset = self.currentDataset?.title
            try? self.saveProject()
            if let _currentDataset = self.currentDataset {
                try? self.loadDataset(dataset: _currentDataset)
                self.sideBarSelection = self.sideBarSelection
                self.labels = _currentDataset.labels.map{ LabelViewModel(label: $0) }
            }
        }
    }

    var currentDatasetPath: URL? {
        guard let _currentDataset = self.currentDataset else {
            return nil
        }
        return self.projectPath?.appending(component: _currentDataset.file)
    }

    @Published var datas: [DataTagWrapper] = []
    @Published var text: String = "" {
        didSet {
            if !self.mutilineMode {
                self.splitWords(text: self.text)
            }else{
                self.splitSentence()
            }
            do {
                try self.saveText()
            } catch {
                print(error)
            }
        }
    }
    
    @Published var sentences: [String] = []
    @Published var selectedSentenceIndex:Int? {
        didSet{
            guard let index = self.selectedSentenceIndex, index >= self.sentences.startIndex, index < self.sentences.endIndex else {
                self.currentDataset?.selectedSentenceIndex = nil
                try? self.saveProject()
                return
            }
            self.currentDataset?.selectedSentenceIndex = index
            try? self.saveProject()
            self.selectSentence = self.sentences[index]
        }
    }
    @Published var selectSentence: String? {
        didSet {
            guard let selectSentence = self.selectSentence else { return }
            self.splitWords(text: selectSentence)
        }
    }
    @Published var lexical: [String] = []
    @Published var pairs: [DataTagPairModel] = []
    @Published var labels: [LabelViewModel] = []

    var usedLexical: [String] = []
    var pair: DataTagPairModel?

    init() {
        self.loadProject()
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.annotateeaseProjectFile]
        if panel.runModal() == .OK, let url = panel.url {
            self.prjectFilePath = url
            self.loadProject()
        }
    }

    func loadProject() {
        guard let _prjectFilePath = self.prjectFilePath else { return }
        do {
            let projectData = try Data(contentsOf: _prjectFilePath.appending(component: "Content.json"))
            self.projectPath = _prjectFilePath.deletingLastPathComponent()
            self.project = try JSONDecoder().decode(Project.self, from: projectData)
            self.mutilineMode = self.project?.mutilineMode ?? false
            self.currentDataset = self.project?.datasets.first{ self.project?.currentDataset == $0.title }
            if let _currentDataset = self.currentDataset {
                try self.loadDataset(dataset: _currentDataset)
            }
        } catch {
            print(error)
        }
    }

    func loadDataset(dataset: Project.Dataset) throws {
        guard let _prjectFilePath = self.prjectFilePath, let _projectPath = self.projectPath else { return }
        let datsetPath = _projectPath.appending(component: dataset.file)
        let jsonData = try Data(contentsOf: datsetPath)
        self.datas = try JSONDecoder().decode([DataTag].self, from: jsonData).map { DataTagWrapper(tag: $0) }
        if let textFileName = dataset.textFile {
            let textFilePath = _prjectFilePath.appending(component: "Texts").appending(component: textFileName).appendingPathExtension("txt")
            self.text = try String(contentsOf: textFilePath, encoding: .utf8)
            self.selectedSentenceIndex = dataset.selectedSentenceIndex
        }
    }

    func saveProject() throws {
        guard let _prjectFilePath = self.prjectFilePath, let project = self.project else {
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try encoder.encode(project).write(to: _prjectFilePath.appending(component: "Content.json"))
    }

    func saveLabels() {
        self.currentDataset?.labels = self.labels.map{ $0.label }
        try? self.saveProject()
    }
    
    func saveText() throws {
        guard let _prjectFilePath = self.prjectFilePath, let _currentDataset = self.currentDataset else { return }
        let textFileName = _currentDataset.textFile ?? UUID().uuidString
        let textsPath = _prjectFilePath.appending(component: "Texts")
        if !FileManager.default.fileExists(atPath: textsPath.path) {
            try FileManager.default.createDirectory(at: textsPath, withIntermediateDirectories: true)
        }
        let textFilePath = _prjectFilePath.appending(component: "Texts").appending(component: textFileName).appendingPathExtension("txt")
        try self.text.write(to: textFilePath, atomically: true, encoding: .utf8)
        _currentDataset.textFile = textFileName
        try self.saveProject()
    }

    func splitSentence() {
        let text = self.text
        var result: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .sentence, scheme: .lexicalClass) { tag, tokenRange -> Bool in
            if let _tag = tag, !HomeViewModel.tags.contains(_tag) {
                result.append(String(text[tokenRange]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
            }
            return true
        }
        self.sentences = result
    }
    
    func splitWords(text: String) {
        var result: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .word, scheme: .lexicalClass,options: .joinContractions) { tag, tokenRange -> Bool in
            if let _tag = tag, !HomeViewModel.tags.contains(_tag) {
                result.append(String(text[tokenRange]))
            }
            return true
        }
        self.lexical = result
        self.pairs.removeAll(keepingCapacity: true)
        self.usedLexical.removeAll(keepingCapacity: true)
        self.pair = nil
    }

    func add(lexical: String) {
        guard !self.usedLexical.contains(lexical) else {
            return
        }
        if self.pair?.label != "" {
            self.pair = nil
        }
        self.usedLexical.append(lexical)
        let vm = self.pair ?? DataTagPairModel()
        vm.lexical.append(lexical)
        self.pair = vm
        self.pairs.removeAll { $0.id == vm.id }
        self.pairs.append(vm)
    }

    func removePari(pari: DataTagPairModel) {
        self.pairs.removeAll(where: { $0.token == pari.token })
        self.usedLexical.removeAll { text in
            pari.lexical.contains(text)
        }
    }

    func clearParis() {
        self.pairs.removeAll()
        self.usedLexical.removeAll()
    }

    func save() {
        guard let _currentDatasetPath = self.currentDatasetPath, !self.pairs.isEmpty else { return }
        let tokens = self.pairs.map { $0.token }
        let labels = self.pairs.map { $0.label }
        var _datas = self.datas
        _datas.append(DataTagWrapper(tag: DataTag(tokens: tokens, labels: labels)))
        do {
            let tags = _datas.map { $0.tag }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(tags).write(to: _currentDatasetPath)
            self.datas = _datas
            if !self.mutilineMode {
                self.text = ""
            }
        } catch {
            debugPrint(error)
        }
    }
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
                ForEach(self.editModel.labels,id:\.id) { label in
                    Text(label.title)
                        .id(label.labelText)
                }
            } label: {}
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
            .onChange(of: isFocused) { isFocused in
                guard !isFocused && !viewModel.labelText.isEmpty && !viewModel.title.isEmpty else { return }
                self.editModel.saveLabels()
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
            .onChange(of: isFocused) { isFocused in
                guard !isFocused && !viewModel.labelText.isEmpty && !viewModel.title.isEmpty else { return }
                self.editModel.saveLabels()
            }
            .frame(maxWidth: .infinity)
            Spacer()
            Button {
                self.editModel.labels.removeAll(where: { $0.id == viewModel.id })
                self.editModel.saveLabels()
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

struct HomeView: View {
    enum TextShowMode:String, CaseIterable {
        case text,sentence
    }
    @StateObject var viewModel = HomeViewModel()
    @State var textShowMode:TextShowMode = .text
    @State var showProjectCreateView:Bool = false
    @State var showDatasetCreateView:Bool = false
    var datasets: some View {
        List(selection: $viewModel.sideBarSelection) {
            if let projectName = self.viewModel.project?.projectName {
                HStack{
                    Image(systemName: "doc.text")
                        .foregroundColor(Color.secondary)
                    Text(projectName)
                }
            }
            HStack {
                Text("Datasets")
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    self.showDatasetCreateView.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showDatasetCreateView) {
                    CreateDatasetView()
                        .environmentObject(self.viewModel)
                }
            }
            .frame(maxWidth: .infinity)
            if let project = self.viewModel.project {
                ForEach(project.datasets, id: \.title) { dataset in
                    Text(dataset.title)
                        .onTapGesture {
                            self.viewModel.currentDataset = dataset
                        }
                        .tag(dataset.title)
                }
            }
        }
        .listStyle(.sidebar)
    }
    
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

    var content: some View {
        VStack {
            HStack {
                Text("Text")
                    .foregroundColor(.secondary)
                Spacer()
                if self.viewModel.mutilineMode {
                    Picker("", selection: $textShowMode) {
                        ForEach(TextShowMode.allCases,id:\.rawValue) {
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
            VStack {
                if textShowMode == .text {
                    TextEditor(text: $viewModel.text)
                        .background(Color.clear)
                        .font(.body)
                        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 100, maxHeight: self.viewModel.mutilineMode ? .infinity : 140)
                }else{
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0){
                            ForEach(Array(self.viewModel.sentences.enumerated()),id:\.offset) { index,sentence in
                                HStack(alignment: .firstTextBaseline){
                                    Text("\(index + 1)")
                                        .font(.footnote)
                                        .foregroundColor(Color.secondary)
                                        .frame(minWidth: 20,alignment: .trailing)
                                    Text(sentence)
                                        .multilineTextAlignment(.leading)
                                        .padding(2)
                                        .frame(maxWidth: .infinity,alignment: .leading)
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
                            }
                        }
                    }
                }
            }
            .padding(4)
            .background(Color(.controlBackgroundColor))
        }
    }

    var mutilineContent: some View {
        VStack(spacing: 0) {
            content
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
                .buttonStyle(.plain)
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
                .buttonStyle(.plain)
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
        }
        .padding(0)
        .frame(minWidth: 300, maxHeight: .infinity)
    }
    
    var editor: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                if !viewModel.mutilineMode {
                    content
                }
                Text("Lexical")
                    .foregroundColor(.secondary)
                VStack {
                    WrappingHStack(id: \.self,
                                   alignment: .topLeading,
                                   horizontalSpacing: 4,
                                   verticalSpacing: 4) {
                        ForEach(viewModel.lexical, id: \.self) { lexical in
                            Text(lexical)
                                .padding(2)
                                .padding(.horizontal, 4)
                                .foregroundColor(self.viewModel.usedLexical.contains(lexical) ? .secondary : .primary)
                                .background(Color.primary.opacity(0.1))
                                .cornerRadius(4)
                                .onTapGesture {
                                    self.viewModel.add(lexical: lexical)
                                }
                        }
                    }
                    Spacer(minLength: 0)
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
                        Image(systemName: "xmark.bin")
                    }
                    .buttonStyle(.plain)
                }
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
                    self.viewModel.save()
                } label: {
                    Text("Save")
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
        }
        .padding(0)
        .frame(minWidth: 400, maxHeight: .infinity)
    }

    var inspector: some View {
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
                }
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
    @State var showInspector = false
    var body: some View {
        NavigationSplitView {
            datasets
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            HSplitView {
                dataList
                if viewModel.mutilineMode {
                    mutilineContent
                }
                editor
            }
            .navigationTitle(self.viewModel.project?.projectName ?? "")
        }
        .inspector(isPresented: $showInspector){
            inspector
                .inspectorColumnWidth(min: 300, ideal: 350, max: 400)
        }
        .frame(maxHeight: .infinity)
        .sheet(isPresented:  $showProjectCreateView){
            CreateView()
                .environmentObject(self.viewModel)
        }
        .onOpenURL {
            if $0.scheme == "AnnotateEase" {
                if $0.host == "create" {
                    self.showProjectCreateView.toggle()
                }
            }else{
                self.viewModel.prjectFilePath = $0
                self.viewModel.loadProject()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    self.showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
            }
        }
    }
}
