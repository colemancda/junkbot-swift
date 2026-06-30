// Translated from Lingo: behavior_config manager.ls

class BehaviorConfigManager: LingoObject, @unchecked Sendable {

    /// Parse a config-file text block into a nested prop list.
    /// - Parameters:
    ///   - t: raw text of the config file
    ///   - defaultList: optional default values (prop list)
    /// - Returns: parsed prop list
    func parseParams(_ t: String, defaultList: PropList? = nil) -> PropList {
        var ret = PropList()
        var section = ret

        let fixed = fixReturns(t)
        let lines = splitLines(fixed)

        for rawLine in lines {
            let L = trim(rawLine)
            if L.isEmpty { continue }

            // Section header: [SectionName] or [SectionName N]
            if L.hasPrefix("[") && L.hasSuffix("]") {
                let sectionName = String(L.dropFirst().dropLast())
                if sectionName == "Master" {
                    section = ret
                } else {
                    let words = splitWords(sectionName)
                    if words.count > 1 {
                        let sectionSym = words[0]
                        let sectionNum = Int(words[1]) ?? 1
                        // Section with index: store as LingoList of PropLists
                        if ret[sectionSym].isVoid {
                            ret[sectionSym] = .list(LingoList())
                        }
                        if let arr = ret[sectionSym].asList {
                            while arr.count < sectionNum {
                                arr.add(.propList(PropList()))
                            }
                            var newSec = PropList()
                            arr[sectionNum] = .propList(newSec)  // 1-based
                            section = newSec
                        }
                    } else {
                        let sectionSym = sectionName
                        if ret[sectionSym].isVoid {
                            ret[sectionSym] = .propList(PropList())
                        }
                        section = ret[sectionSym].asPropList ?? PropList()
                    }
                }
                continue
            }

            // Comment line
            if L.hasPrefix("--") { continue }

            // Key=value pairs (comma-separated items on line)
            let items = splitCommas(L)
            var pkey: String = ""

            for item in items {
                let pval: String
                if let eqIdx = item.firstIndex(of: "=") {
                    pkey = String(item[item.startIndex..<eqIdx])
                    pval = String(item[item.index(after: eqIdx)...])
                } else {
                    if pkey.isEmpty { continue }
                    pval = item
                }

                let pvalTrimmed = trimWhitespace(pval)
                let pvalVal: LV
                if let i = Int(pvalTrimmed) {
                    pvalVal = .int(i)
                } else if let f = Float(pvalTrimmed) {
                    pvalVal = .float(f)
                } else {
                    pvalVal = .string(pvalTrimmed)
                }

                if pkey.isEmpty { continue }
                let existing = section[pkey]
                if existing.isVoid {
                    section[pkey] = pvalVal
                } else if existing.isList {
                    existing.asList?.add(pvalVal)
                } else {
                    let newList = LingoList()
                    newList.add(existing)
                    newList.add(pvalVal)
                    section[pkey] = .list(newList)
                }
            }
        }

        // Apply defaults
        if let defaults = defaultList {
            for i in 1...max(1, defaults.count) {
                guard i <= defaults.count else { break }
                let (k, v) = defaults.getPropAt(i)
                if ret[k].isVoid {
                    ret[k] = v
                }
            }
        }

        return ret
    }

    /// Serialize a nested prop list back to config-file text.
    func toString(_ propLists: [(String, PropList)]) -> String {
        var result = ""
        for (bracketName, bracket) in propLists {
            result += "[\(bracketName)]\n"
            for i in 1...max(1, bracket.count) {
                guard i <= bracket.count else { break }
                let keyName = bracket.getPropAt(i)
                let keyVal = bracket[keyName]
                if let arr = keyVal.asList {
                    var t = "\(keyName)="
                    for j in 1...max(1, arr.count) {
                        guard j <= arr.count else { break }
                        let v = arr[j]
                        t += lvToString(v)
                        if j < arr.count {
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
                    result += "\(keyName)=\(lvToString(keyVal))\n"
                }
            }
            result += "\n\n"
        }
        return result
    }

    /// Join a list value back into a comma-separated string.
    func restoreCommas(_ val: LV) -> String {
        if let arr = val.asList {
            var parts: [String] = []
            for i in 1...max(1, arr.count) {
                guard i <= arr.count else { break }
                parts.append(lvToString(arr[i]))
            }
            return parts.joined(separator: ",")
        }
        return lvToString(val)
    }

    // MARK: - String helpers (no Foundation)

    func lvToString(_ v: LV) -> String {
        switch v {
        case .int(let n): return "\(n)"
        case .float(let f): return "\(f)"
        case .string(let s): return s
        default: return ""
        }
    }

    /// Remove CR/LF characters from a string.
    func cleanWhitespace(_ t: String) -> String {
        var result = ""
        for c in t.unicodeScalars {
            if c.value != 0x0A && c.value != 0x0D {
                result.unicodeScalars.append(c)
            }
        }
        return result
    }

    /// Normalize all line endings to \n.
    func fixReturns(_ t: String) -> String {
        var result = ""
        var prev: Unicode.Scalar? = nil
        for c in t.unicodeScalars {
            if c.value == 0x0A {
                if prev?.value == 0x0D {
                    // already wrote \n for the \r
                } else {
                    result.append("\n")
                }
            } else if c.value == 0x0D {
                result.append("\n")
            } else {
                result.unicodeScalars.append(c)
            }
            prev = c
        }
        return result
    }

    /// Split a string on \n.
    func splitLines(_ t: String) -> [String] {
        var lines: [String] = []
        var current = ""
        for c in t {
            if c == "\n" {
                lines.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// Split on commas.
    func splitCommas(_ t: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for c in t {
            if c == "," {
                parts.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        parts.append(current)
        return parts
    }

    /// Split on spaces, filtering empties.
    func splitWords(_ t: String) -> [String] {
        var words: [String] = []
        var current = ""
        for c in t {
            if c == " " || c == "\t" {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    /// Trim leading and trailing whitespace (space, \n, \t, \r).
    func trim(_ t: String) -> String {
        return trimWhitespace(t)
    }

    func trimWhitespace(_ t: String) -> String {
        var scalars = Array(t.unicodeScalars)
        while let first = scalars.first, isWS(first) { scalars.removeFirst() }
        while let last = scalars.last, isWS(last) { scalars.removeLast() }
        var s = ""
        for sc in scalars { s.unicodeScalars.append(sc) }
        return s
    }

    func isWS(_ s: Unicode.Scalar) -> Bool {
        return s.value == 32 || s.value == 9 || s.value == 10 || s.value == 13
    }
}
