// Translated from Lingo: behavior_config manager.ls

import Foundation

class BehaviorConfigManager {

    /// Parse a config-file text block into a nested dictionary.
    /// - Parameters:
    ///   - t: raw text of the config file
    ///   - defaultList: optional default values (prop list)
    /// - Returns: parsed dictionary
    func parseParams(_ t: String, defaultList: [String: Any]? = nil) -> [String: Any] {
        var ret: [String: Any] = [:]
        var section: [String: Any] = ret

        let fixed = fixReturns(t)
        let lines = fixed.components(separatedBy: "\n")

        for rawLine in lines {
            let L = trim(rawLine)
            if L.isEmpty { continue }

            // Section header: [SectionName] or [SectionName N]
            if L.hasPrefix("[") && L.hasSuffix("]") {
                let sectionName = String(L.dropFirst().dropLast())
                if sectionName == "Master" {
                    section = ret
                } else {
                    let words = sectionName.components(separatedBy: " ").filter { !$0.isEmpty }
                    if words.count > 1 {
                        let sectionSym = words[0]
                        let sectionNum = Int(words[1]) ?? 1
                        if ret[sectionSym] == nil {
                            ret[sectionSym] = [[String: Any]]()
                        }
                        if var arr = ret[sectionSym] as? [[String: Any]] {
                            while arr.count < sectionNum {
                                arr.append([:])
                            }
                            arr[sectionNum - 1] = [:]
                            ret[sectionSym] = arr
                            section = arr[sectionNum - 1]
                        }
                    } else {
                        let sectionSym = sectionName
                        if ret[sectionSym] == nil {
                            ret[sectionSym] = [String: Any]()
                        }
                        section = (ret[sectionSym] as? [String: Any]) ?? [:]
                    }
                }
                continue
            }

            // Comment line
            if L.hasPrefix("--") { continue }

            // Key=value pairs (comma-separated items on line)
            let items = L.components(separatedBy: ",")
            var pkey: String? = nil

            for item in items {
                let eqRange = item.range(of: "=")
                let pval: String
                if let eq = eqRange {
                    pkey = String(item[item.startIndex..<eq.lowerBound])
                    pval = String(item[eq.upperBound...])
                } else {
                    guard pkey != nil else { continue }
                    pval = item
                }

                let pvalTrimmed = pval.trimmingCharacters(in: .whitespaces)
                let pvalVal: Any
                if let f = Double(pvalTrimmed) {
                    if f == Double(Int(f)) {
                        pvalVal = Int(f)
                    } else {
                        pvalVal = f
                    }
                } else {
                    pvalVal = pvalTrimmed
                }

                guard let key = pkey else { continue }
                if let existing = section[key] {
                    if var arr = existing as? [Any] {
                        arr.append(pvalVal)
                        section[key] = arr
                    } else {
                        section[key] = [existing, pvalVal]
                    }
                } else {
                    section[key] = pvalVal
                }
            }
        }

        // Apply defaults
        if let defaults = defaultList {
            for (k, v) in defaults {
                if ret[k] == nil {
                    ret[k] = v
                }
            }
        }

        return ret
    }

    /// Serialize a nested dictionary back to config-file text.
    func toString(_ propLists: [[String: [String: Any]]]) -> String {
        var result = ""
        for pl in propLists {
            for (bracketName, bracket) in pl {
                result += "[\(bracketName)]\n"
                for (keyName, keyVal) in bracket {
                    if let arr = keyVal as? [Any] {
                        var t = "\(keyName)="
                        for (idx, v) in arr.enumerated() {
                            t += "\(v)"
                            if idx < arr.count - 1 {
                                if t.count > 60 {
                                    result += t + "\n"
                                    t = "\(keyName)="
                                } else {
                                    t += ","
                                }
                            }
                        }
                        result += t + "\n"
                    } else {
                        result += "\(keyName)=\(keyVal)\n"
                    }
                }
                result += "\n\n"
            }
        }
        return result
    }

    /// Join a list back into a comma-separated string.
    func restoreCommas(_ t: Any) -> String {
        if let arr = t as? [Any] {
            return arr.map { "\($0)" }.joined(separator: ",")
        }
        return "\(t)"
    }

    /// Remove CR/LF characters from a string.
    func cleanWhitespace(_ t: String) -> String {
        return t
            .replacingOccurrences(of: "\u{0A}", with: "")
            .replacingOccurrences(of: "\u{0D}", with: "")
    }

    /// Normalize all line endings to \n.
    func fixReturns(_ t: String) -> String {
        return t
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Trim leading and trailing whitespace (space, \n, \t) from a string.
    func trim(_ t: String) -> String {
        let whitespace = CharacterSet(charactersIn: " \n\t\r")
        return t.trimmingCharacters(in: whitespace)
    }
}
