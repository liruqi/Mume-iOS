//
//  RegexUtils.swift
//  Potatso
//
//  Created by LEI on 6/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class Regex {

    let internalExpression: NSRegularExpression
    let pattern: String

    init(_ pattern: String) throws {
        self.pattern = pattern
        self.internalExpression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }

    func test(_ input: String) -> Bool {
        let matches = self.internalExpression.matches(in: input, options: NSRegularExpression.MatchingOptions.reportCompletion, range:NSMakeRange(0, input.characters.count))
        return matches.count > 0
    }

    // return group of the first matching text
    func capturedGroup(string: String) -> [String]? {
        
        let matches = internalExpression.matches(in: string, options: [], range: NSRange(location:0, length: string.characters.count))
        
        guard let match = matches.first else { return nil }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return nil }

        var results = [String]()
        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.rangeAt(i)
            let matchedString = (string as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }
        
        return results
    }
}
