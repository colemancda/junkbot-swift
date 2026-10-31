import Foundation
import JunkbotBackend
import JunkbotCore

// Save data without Codable, which Embedded Swift lacks: one "moves<TAB>title"
// line per completed level, in the app's Documents directory.

let saveDataPath: String = {
  let documents = jb_documents_path()!
  defer { jb_free(documents) }
  return String(cString: documents) + "/save.txt"
}()

func loadSaveData() -> SaveData {
  var length: UInt = 0
  guard let contents = jb_file_read(saveDataPath, &length) else { return SaveData() }
  defer { jb_free(contents) }
  var saveData = SaveData()
  for line in String(cString: contents).split(separator: "\n") {
    guard let tab = line.firstIndex(of: "\t"), let moves = Int(line[..<tab]) else { continue }
    saveData.bestMoves[String(line[line.index(after: tab)...])] = moves
  }
  return saveData
}

@GameActor func writeSaveData() {
  var contents = ""
  for (title, moves) in saveData.bestMoves {
    contents += "\(moves)\t\(title)\n"
  }
  var bytes = Array(contents.utf8)
  if jb_file_write(saveDataPath, &bytes, UInt(bytes.count)) == 0 {
    FileHandle.standardError.write(Data("Failed to write save data to \(saveDataPath)\n".utf8))
  }
}
