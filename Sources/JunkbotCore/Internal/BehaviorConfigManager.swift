// Translated from Lingo: behavior_config manager.ls

class BehaviorConfigManager: LingoObject, @unchecked Sendable {

  /// Parse a config-file text block into a nested prop list.
  /// - Parameters:
  ///   - t: raw text of the config file
  ///   - defaultList: optional default values (prop list)
  /// - Returns: parsed prop list
  // Original Lingo body: parseparams
  // ```lingo
  // on parseParams me, t, defaultList
  //   ret = [:]
  //   section = ret
  //   the itemDelimiter = ","
  //   t = me.fixReturns(t)
  //   repeat with ln = 1 to t.line.count
  //     L = me.trim(t.line[ln])
  //     if L.length = 0 then
  //       next repeat
  //     end if
  //     if (L.char[1] = "[") and (L.char[L.char.count] = "]") then
  //       section_name = L.char[2..L.char.count - 1]
  //       if section_name = "Master" then
  //         section = ret
  //       else
  //         if section_name.word.count > 1 then
  //           section_num = integer(section_name.word[2])
  //           section_sym = symbol(section_name.word[1])
  //           if ilk(ret[section_sym]) <> #list then
  //             ret[section_sym] = []
  //           end if
  //           ret[section_sym][section_num] = [:]
  //           section = ret[section_sym][section_num]
  //         else
  //           section_sym = symbol(section_name)
  //           if ilk(ret[section_sym]) <> #propList then
  //             ret[section_sym] = [:]
  //           end if
  //           section = ret[section_sym]
  //         end if
  //       end if
  //       next repeat
  //     end if
  //     if L.char[1..2] = "--" then
  //       next repeat
  //     end if
  //     pkey = VOID
  //     repeat with pn = 1 to L.item.count
  //       p = L.item[pn]
  //       d = offset("=", p)
  //       if d = 0 then
  //         if ilk(pkey) = #void then
  //           next repeat
  //         end if
  //         pval = p
  //       else
  //         pkey = p.char[1..d - 1]
  //         pval = p.char[d + 1..p.char.count]
  //       end if
  //       pval_val = float(pval)
  //       if integer(pval_val) = pval_val then
  //         pval_val = integer(pval_val)
  //       end if
  //       pkey_sym = symbol(pkey)
  //       if ilk(section[pkey_sym]) <> #void then
  //         if ilk(section[pkey_sym]) = #list then
  //           section[pkey_sym].add(pval_val)
  //         else
  //           section[pkey_sym] = [section[pkey_sym], pval_val]
  //         end if
  //         next repeat
  //       end if
  //       section[pkey_sym] = pval_val
  //     end repeat
  //   end repeat
  //   if ilk(defaultList) = #propList then
  //     repeat with i = 1 to defaultList.count
  //       if ret[defaultList.getPropAt(i)] = VOID then
  //         ret[defaultList.getPropAt(i)] = defaultList[i]
  //       end if
  //     end repeat
  //   end if
  //   return ret
  // end
  // ```
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
  // Original Lingo body: tostring
  // ```lingo
  // on toString me
  //   stringval = EMPTY
  //   repeat with pn = 2 to the paramCount
  //     pl = param(pn)
  //     repeat with bn = 1 to pl.count
  //       bracketname = pl.getPropAt(bn)
  //       stringval = stringval & "[" & bracketname & "]" & RETURN
  //       bracket = pl[bn]
  //       repeat with kn = 1 to bracket.count
  //         keyname = bracket.getPropAt(kn)
  //         keyval = bracket[kn]
  //         if ilk(keyval) = #list then
  //           t = keyname & "="
  //           repeat with v = 1 to keyval.count
  //             t = t & keyval[v]
  //             if v < keyval.count then
  //               if length(t) > 60 then
  //                 stringval = stringval & t & RETURN
  //                 t = keyname & "="
  //                 next repeat
  //               end if
  //               t = t & ","
  //             end if
  //           end repeat
  //           stringval = stringval & t & RETURN
  //           next repeat
  //         end if
  //         stringval = stringval & keyname & "=" & keyval & RETURN
  //       end repeat
  //       stringval = stringval & RETURN & RETURN
  //     end repeat
  //   end repeat
  //   return stringval
  // end
  // ```
  func toString(_ propLists: [(String, PropList)]) -> String {
    var result = ""
    for (bracketName, bracket) in propLists {
      result += "[\(bracketName)]\n"
      for i in 1...max(1, bracket.count) {
        guard i <= bracket.count else { break }
        let (keyName, keyVal) = bracket.getPropAt(i)
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

  /// Serialize a single prop list back to config-file text (convenience overload).
  // Original Lingo body: tostring
  // ```lingo
  // on toString me
  //   stringval = EMPTY
  //   repeat with pn = 2 to the paramCount
  //     pl = param(pn)
  //     repeat with bn = 1 to pl.count
  //       bracketname = pl.getPropAt(bn)
  //       stringval = stringval & "[" & bracketname & "]" & RETURN
  //       bracket = pl[bn]
  //       repeat with kn = 1 to bracket.count
  //         keyname = bracket.getPropAt(kn)
  //         keyval = bracket[kn]
  //         if ilk(keyval) = #list then
  //           t = keyname & "="
  //           repeat with v = 1 to keyval.count
  //             t = t & keyval[v]
  //             if v < keyval.count then
  //               if length(t) > 60 then
  //                 stringval = stringval & t & RETURN
  //                 t = keyname & "="
  //                 next repeat
  //               end if
  //               t = t & ","
  //             end if
  //           end repeat
  //           stringval = stringval & t & RETURN
  //           next repeat
  //         end if
  //         stringval = stringval & keyname & "=" & keyval & RETURN
  //       end repeat
  //       stringval = stringval & RETURN & RETURN
  //     end repeat
  //   end repeat
  //   return stringval
  // end
  // ```
  func toString(_ wrapper: PropList) -> String {
    return toString([("Master", wrapper)])
  }

  /// Join a list value back into a comma-separated string.
  // Original Lingo body: restorecommas
  // ```lingo
  // on restoreCommas me, t
  //   if ilk(t) <> #list then
  //     return t
  //   end if
  //   r = EMPTY
  //   repeat with i = 1 to t.count
  //     r = r & t[i]
  //     if i <> t.count then
  //       r = r & ","
  //     end if
  //   end repeat
  //   return r
  // end
  // ```
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
  // Original Lingo body: cleanwhitespace
  // ```lingo
  // on cleanWhitespace me, t
  //   repeat while offset(numToChar(10), t) > 0
  //     delete char offset(numToChar(10), t) of t
  //   end repeat
  //   repeat while offset(numToChar(13), t) > 0
  //     delete char offset(numToChar(13), t) of t
  //   end repeat
  //   return t
  // end
  // ```
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
  // Original Lingo body: fixreturns
  // ```lingo
  // on fixReturns me, t
  //   repeat while offset(numToChar(10), t) > 0
  //     put RETURN into me.char[offset(numToChar(10), t)]
  //   end repeat
  //   return t
  // end
  // ```
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
  // Original Lingo body: trim
  // ```lingo
  // on trim me, t
  //   whitespace = " " & RETURN & TAB & numToChar(10)
  //   repeat while (whitespace contains char 1 of t) and (t.length > 0)
  //     delete char 1 of t
  //   end repeat
  //   repeat while (whitespace contains the last char in t) and (t.length > 0)
  //     delete char -30000 of t
  //   end repeat
  //   return t
  // end
  // ```
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
