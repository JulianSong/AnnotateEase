//
//  ContentView.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/11.
//

import NaturalLanguage
import SwiftUI
import UniformTypeIdentifiers

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
            guard let index = self.selectedSentenceIndex,index >= self.sentences.startIndex, index < self.sentences.endIndex else {
                self.currentDataset?.selectedSentenceIndex = nil
                Task{
                    do {
                        try await self.saveProject()
                    }catch{
                        print(error)
                    }
                }
                return
            }
            Task{
                do {
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
            self.selectedSentenceIndex = nil
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
        if dataset.mutilineMode == true {
            try await self.splitSentence()
            self.selectedSentenceIndex = dataset.selectedSentenceIndex
        }
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
    
    func save() async {
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
                self.currentDataset?.selectedSentenceIndex = self.selectedSentenceIndex
                try await self.saveProject()
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

struct MainView: View {
    @StateObject var viewModel = HomeViewModel()
    @State var showProjectCreateView:Bool = false
    @State var showDatasetCreateView:Bool = false
    @State var showInspector = false
    var datasets: some View {
        List(selection: $viewModel.currentDataset) {
            if let projectName = self.viewModel.project?.projectName {
                HStack{
                    Image(systemName: "doc.text")
                        .foregroundColor(Color.secondary)
                    Text(projectName)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
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
    
    
    var body: some View {
        NavigationSplitView {
            datasets
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            DatasetView(viewModel: self.viewModel)
        }
        .inspector(isPresented: $showInspector){
            DatasetInspector(viewModel: self.viewModel)
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
