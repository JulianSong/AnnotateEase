//
//  LocalizedAlertError.swift
//  AnnotateEase
//
//  Created by julian on 2024/3/6.
//  Copyright © 2024 Julian.Song. All rights reserved.
//

import Foundation

struct LocalizedAlertError: LocalizedError {
    let underlyingError: LocalizedError
    var errorDescription: String? {
        underlyingError.errorDescription
    }
    var recoverySuggestion: String? {
        underlyingError.recoverySuggestion
    }

    init?(error: Error?) {
        guard let localizedError = error as? LocalizedError else { return nil }
        underlyingError = localizedError
    }
}
