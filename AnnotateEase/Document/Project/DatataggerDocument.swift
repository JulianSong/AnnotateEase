//
//  DatatagDocument.swift
//  DataTagger
//
//  Created by Julian.Song on 2023/5/15.
//

import SwiftUI
import UniformTypeIdentifiers

class Project: Codable {
    class Dataset: Codable, Hashable {
        struct Label: Codable,Identifiable,Equatable {
            var id: String = UUID().uuidString
            let label:String
            let title:String
            
            enum CodingKeys: CodingKey {
                case label
                case title
            }
            static func empty() -> Self { Label(label: "", title: "") }
        }
        enum TextShowMode:String, CaseIterable,Codable {
            case text,sentence
        }
        let title:String
        let type:String
        let file:String
        var labels:[Project.Dataset.Label]
        var textFile:String?
        var textShowMode: TextShowMode? = .text
        var mutilineMode: Bool? = false
        var selectedSentenceIndex:Int?
        init(title: String, type: String, file: String, labels: [Project.Dataset.Label], textFile: String? = nil, mutilineMode: Bool? = nil, selectedSentenceIndex: Int? = nil) {
            self.title = title
            self.type = type
            self.file = file
            self.labels = labels
            self.textFile = textFile
            self.mutilineMode = mutilineMode
            self.selectedSentenceIndex = selectedSentenceIndex
        }
        
        static func == (lhs: Project.Dataset, rhs: Project.Dataset) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.title)
            hasher.combine(self.type)
            hasher.combine(self.file)
        }
    }
    
    var projectName: String
    var datasets:[Dataset] = []
    var openedDataSets:[String]?
    var currentDataset:String?
    init(projectName:String) {
        self.projectName = projectName
    }
    
    func save(to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        try encoder.encode(self).write(to: url.appending(component: "Content.json"))
    }
}

struct DataTagPair: Identifiable {
    var id: String = UUID().uuidString
    var token: String
    var label: String
}

struct DataTag: Codable {
    var tokens: [String]
    var labels: [String]
    var pairs: [DataTagPair] {
        var pairs: [DataTagPair] = []
        for (index, token) in self.tokens.enumerated() {
            pairs.append(DataTagPair(token: token, label: self.labels[index]))
        }
        return pairs
    }
}

struct DataTagWrapper: Identifiable {
    var id: String = UUID().uuidString
    var tag: DataTag
}

extension UTType {
    static var annotateeaseProjectFile = UTType(exportedAs: "studio.peachtree.annotateease.aegr")
}

extension Project.Dataset {
    static func tags(datsetPath:URL) async throws -> [DataTagWrapper]? {
        guard FileManager.default.fileExists(atPath: datsetPath.path) else {
            return nil
        }
        let jsonData = try Data(contentsOf: datsetPath)
        return try JSONDecoder().decode([DataTag].self, from: jsonData).map { DataTagWrapper(tag: $0) }
    }
    
    static func text(textFilePath:URL) async throws -> String? {
        guard FileManager.default.fileExists(atPath: textFilePath.path) else {
            return nil
        }
        return try String(contentsOf: textFilePath, encoding: .utf8)
    }
}
