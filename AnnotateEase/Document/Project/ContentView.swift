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

extension String {
    func splitSentence() async -> [Self] {
        let tags: Set<NLTag> = [.whitespace, .paragraphBreak]
        var result: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = self
        tagger.enumerateTags(in: self.startIndex ..< self.endIndex, unit: .sentence, scheme: .lexicalClass) { tag, tokenRange -> Bool in
            if let _tag = tag, !tags.contains(_tag) {
                result.append(String(self[tokenRange]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
            }
            return true
        }
        return result
    }
    
    func splitWords() async -> [(String,Range<String.Index>)] {
        let tags: Set<NLTag> = [.whitespace, .paragraphBreak]
        var result: [(String,Range<String.Index>)] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = self
        tagger.enumerateTags(in: self.startIndex ..< self.endIndex, unit: .word, scheme: .lexicalClass,options: .joinContractions) { tag, tokenRange -> Bool in
            if let _tag = tag, !tags.contains(_tag) {
                result.append((String(self[tokenRange]),tokenRange))
            }
            return true
        }
        return result
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var project: Project?
    @Published var currentDataset: Project.Dataset? {
        didSet {
            self.project?.currentDataset = self.currentDataset?.title
            self.mutilineMode = self.currentDataset?.mutilineMode ?? self.mutilineMode
            self.textShowMode = self.currentDataset?.textShowMode ?? self.textShowMode
            Task{
                do {
                    try await self.saveProject()
                    if let _currentDataset = self.currentDataset {
                        try await self.loadDataset(dataset: _currentDataset)
                    }else{
                        self.pairs.removeAll()
                        self.lexical.removeAll()
                        self.labels.removeAll()
                        self.datas.removeAll()
                    }
                }catch{
                    print(error)
                }
            }
        }
    }
    @Published var datas: [DataTagWrapper] = []
    @Published var sentences: [String] = []
    @Published var selectedSentenceIndex:Int? {
        didSet{
            Task{
                do {
                    guard let index = self.selectedSentenceIndex, index >= self.sentences.startIndex, index < self.sentences.endIndex else {
                        self.currentDataset?.selectedSentenceIndex = nil
                        try await self.saveProject()
                        return
                    }
                    self.currentDataset?.selectedSentenceIndex = index
                    try await self.saveProject()
                    self.selectSentence = self.sentences[index]
                }catch{
                    print(error)
                }
            }
        }
    }
    @Published var selectSentence: String? {
        didSet {
            Task{
                guard let selectSentence = self.selectSentence else { return }
                await self.splitWords(text: selectSentence)
            }
        }
    }
    @Published var lexical: [(String,Range<String.Index>)] = []
    @Published var pairs: [DataTagPairModel] = []
    @Published var labels: [LabelViewModel] = []
    @Published var textShowMode:Project.Dataset.TextShowMode = .text {
        didSet {
            Task{
                do {
                    self.currentDataset?.textShowMode = self.textShowMode
                    try await self.saveProject()
                } catch {
                    print(error)
                }
            }
        }
    }
    @Published var text: String = "" {
        didSet {
            Task{
                if !self.mutilineMode {
                    await self.splitWords(text: self.text)
                }else{
                    await self.splitSentence()
                }
                do {
                    try await self.saveText()
                } catch {
                    print(error)
                }
            }
        }
    }

    @Published var mutilineMode = false {
        didSet {
            Task{
                if self.mutilineMode {
                    await self.splitSentence()
                    self.lexical.removeAll()
                }else{
                    await self.splitWords(text: self.text)
                }
                do {
                    self.currentDataset?.mutilineMode = self.mutilineMode
                    try await self.saveProject()
                }catch {
                    print(error)
                }
            }
        }
    }

    var prjectFilePath: URL?
    var projectPath: URL?
    var usedLexical: [(String,Range<String.Index>)] = []
    var pair: DataTagPairModel?
    var currentDatasetPath: URL? {
        guard let _currentDataset = self.currentDataset else {
            return nil
        }
        return self.projectPath?.appending(component: _currentDataset.file)
    }
    
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
        Task{
            do {
                let projectData = try Data(contentsOf: _prjectFilePath.appending(component: "Content.json"))
                self.projectPath = _prjectFilePath.deletingLastPathComponent()
                self.project = try JSONDecoder().decode(Project.self, from: projectData)
                self.currentDataset = self.project?.datasets.first{ self.project?.currentDataset == $0.title }
                if let _currentDataset = self.currentDataset {
                    try await self.loadDataset(dataset: _currentDataset)
                }
            } catch {
                print(error)
            }
        }
    }

    func loadDataset(dataset: Project.Dataset) async throws {
        guard 
            let _prjectFilePath = self.prjectFilePath,
            let _projectPath = self.projectPath,
            let textFileName = dataset.textFile
        else {
            self.datas = []
            self.text = ""
            self.selectedSentenceIndex = 0
            self.labels = dataset.labels.map{ LabelViewModel(label: $0) }
            return
        }
        self.labels = dataset.labels.map{ LabelViewModel(label: $0) }
            let textFilePath = _prjectFilePath.appending(component: "Texts").appending(component: textFileName).appendingPathExtension("txt")
        
        async let text = Project.Dataset.text(textFilePath: textFilePath) ?? ""
        async let datas = Project.Dataset.tags(datsetPath: _projectPath.appending(component: dataset.file)) ?? []
        let result = try await [datas,text] as [Any]
        self.datas = result.first as! [DataTagWrapper]
        self.text = result.last as! String
        self.selectedSentenceIndex = dataset.selectedSentenceIndex
    }

    func saveProject() async throws {
        guard let _prjectFilePath = self.prjectFilePath else {
            return
        }
        try await self.project?.save(to: _prjectFilePath)
    }

    func saveLabels() async throws {
        self.currentDataset?.labels = self.labels.map{ $0.label }
        try await self.saveProject()
    }
    
    func saveText() async throws {
        guard let _prjectFilePath = self.prjectFilePath, let _currentDataset = self.currentDataset else { return }
        let textFileName = _currentDataset.textFile ?? UUID().uuidString
        let textsPath = _prjectFilePath.appending(component: "Texts")
        if !FileManager.default.fileExists(atPath: textsPath.path) {
            try FileManager.default.createDirectory(at: textsPath, withIntermediateDirectories: true)
        }
        let textFilePath = _prjectFilePath.appending(component: "Texts").appending(component: textFileName).appendingPathExtension("txt")
        try self.text.write(to: textFilePath, atomically: true, encoding: .utf8)
        _currentDataset.textFile = textFileName
        try await self.saveProject()
    }

    func splitSentence() async {
        self.sentences = await self.text.splitSentence()
    }
    
    func splitWords(text: String)  async {
        self.lexical = await text.splitWords()
        self.pairs.removeAll(keepingCapacity: true)
        self.usedLexical.removeAll(keepingCapacity: true)
        self.pair = nil
    }

    func add(lexical: (String,Range<String.Index>))  {
        guard !self.usedLexical.contains(where: { $0.1 == lexical.1 } ) else {
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

    func removeData(data: DataTagWrapper) {
        guard let _currentDatasetPath = self.currentDatasetPath else { return }
        do {
            var _datas = self.datas
            _datas.removeAll {
                $0.id == data.id
            }
            let tags = _datas.map { $0.tag }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(tags).write(to: _currentDatasetPath)
            self.datas = _datas
        } catch {
            debugPrint(error)
        }
    }
    
    func removePari(pari: DataTagPairModel) {
        self.pairs.removeAll(where: { $0.id == pari.id })
        self.usedLexical.removeAll { lexical in
            pari.lexical.contains(where: { $0.1 == lexical.1 })
        }
        if self.pair?.id == pari.id {
            self.pair = nil
        }
    }

    func clearParis() {
        self.pair = nil
        self.pairs.removeAll()
        self.usedLexical.removeAll()
    }

    func resetData() {
        
    }
    
    func save() {
        guard let _currentDatasetPath = self.currentDatasetPath, !self.pairs.isEmpty else { return }
        let tokens = self.pairs.compactMap { $0.token }
        let labels = self.pairs.compactMap { $0.label }
        var _datas = self.datas
        _datas.append(DataTagWrapper(tag: DataTag(tokens: tokens, labels: labels)))
        do {
            let tags = _datas.map { $0.tag }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(tags).write(to: _currentDatasetPath)
            self.datas = _datas
            self.pairs.removeAll()
            guard self.lexical.count == self.usedLexical.count else { return }
            self.lexical.removeAll()
            if !self.mutilineMode {
                self.text = ""
            }else{
                self.usedLexical.removeAll()
                guard let index = self.selectedSentenceIndex,(index + 1) < self.sentences.endIndex else { return }
                self.selectedSentenceIndex = index + 1
            }
        } catch {
            debugPrint(error)
        }
    }
    
    func deleteDataset(dataset: Project.Dataset) async throws {
        do{
            self.project?.datasets.removeAll{ ds in
                ds == dataset
            }
            try await self.saveProject()
            if self.currentDataset == dataset{
                self.currentDataset = nil
                self.currentDataset = self.project?.datasets.first
            }
        }catch{
            throw error
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

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @State var showProjectCreateView:Bool = false
    @State var showDatasetCreateView:Bool = false
    var datasets: some View {
        List(selection: $viewModel.currentDataset) {
            if let projectName = self.viewModel.project?.projectName {
                HStack{
                    Image(systemName: "doc.text")
                        .foregroundColor(Color.secondary)
                    Text(projectName)
                }
            }
            Section{
                if let project = self.viewModel.project {
                    ForEach(project.datasets, id: \.title) { dataset in
                        Text(dataset.title)
                            .onTapGesture {
                                self.viewModel.currentDataset = dataset
                            }
                            .tag(dataset)
                            .contextMenu {
                                Button(action: {
                                    guard let projectPath = self.viewModel.projectPath else {
                                        return
                                    }
                                    let datsetPath = projectPath.appending(component: dataset.file)
                                    NSWorkspace.shared.selectFile(datsetPath.path, inFileViewerRootedAtPath: projectPath.path)
                                }, label: {
                                    Text("Show In Finder")
                                })
                                Divider()
                                Button(action: {
                                    Task{
                                        try? await self.viewModel.deleteDataset(dataset: dataset)
                                    }
                                }, label: {
                                    Text("Delete")
                                })
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Datasets")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        self.showDatasetCreateView.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 30)
                    }
                    .buttonStyle(.plain)
                    .disabled(self.viewModel.project == nil)
                }
                .frame(maxWidth: .infinity)
            }
            .collapsible(false)
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showDatasetCreateView) {
            CreateDatasetView()
                .environmentObject(self.viewModel)
        }
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
                        .background(Color.clear)
                        .font(.body)
                        .lineSpacing(5)
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
                                    .id(index)
                                }
                            }
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
                    self.viewModel.save()
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
    @State var showInspector = false
    var body: some View {
        NavigationSplitView {
            datasets
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            HSplitView {
                dataList
                if viewModel.mutilineMode {
                    mutilineTextContent
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
