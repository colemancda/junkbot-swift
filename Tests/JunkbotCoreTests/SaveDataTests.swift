import Foundation
import Testing

@testable import JunkbotCore

@Suite("Save data")
struct SaveDataTests {

  @Test("Recording a win for a level with no prior score always improves")
  func firstWinAlwaysImproves() {
    var save = SaveData()
    let improved = save.recordWin(levelTitle: "Tippy Toast", moves: 5)
    #expect(improved)
    #expect(save.bestMoves["Tippy Toast"] == 5)
  }

  @Test("A strictly better (lower) move count improves the recorded best")
  func betterMovesImproves() {
    var save = SaveData(bestMoves: ["Tippy Toast": 10])
    let improved = save.recordWin(levelTitle: "Tippy Toast", moves: 5)
    #expect(improved)
    #expect(save.bestMoves["Tippy Toast"] == 5)
  }

  @Test("An equal move count still counts as an improvement (matches JS's >= gate)")
  func equalMovesStillImproves() {
    var save = SaveData(bestMoves: ["Tippy Toast": 5])
    let improved = save.recordWin(levelTitle: "Tippy Toast", moves: 5)
    #expect(improved)
    #expect(save.bestMoves["Tippy Toast"] == 5)
  }

  @Test("A worse (higher) move count does not overwrite the recorded best")
  func worseMovesDoesNotOverwrite() {
    var save = SaveData(bestMoves: ["Tippy Toast": 5])
    let improved = save.recordWin(levelTitle: "Tippy Toast", moves: 10)
    #expect(!improved)
    #expect(save.bestMoves["Tippy Toast"] == 5)
  }

  @Test("isCompleted reflects presence of a recorded score")
  func isCompleted() {
    var save = SaveData()
    #expect(!save.isCompleted(levelTitle: "Tippy Toast"))
    save.recordWin(levelTitle: "Tippy Toast", moves: 5)
    #expect(save.isCompleted(levelTitle: "Tippy Toast"))
  }

  @Test("isGold requires a recorded score at or under par")
  func isGold() {
    var save = SaveData()
    #expect(!save.isGold(levelTitle: "Tippy Toast", par: 3))
    save.recordWin(levelTitle: "Tippy Toast", moves: 5)
    #expect(!save.isGold(levelTitle: "Tippy Toast", par: 3))
    #expect(save.isGold(levelTitle: "Tippy Toast", par: 5))
    #expect(save.isGold(levelTitle: "Tippy Toast", par: 10))
    #expect(!save.isGold(levelTitle: "Tippy Toast", par: nil))
  }

  @Test("Round-trips through JSON encode/decode")
  func codableRoundTrip() throws {
    var save = SaveData()
    save.recordWin(levelTitle: "Tippy Toast", moves: 5)
    save.recordWin(levelTitle: "Shallow Steps", moves: 12)

    let data = try JSONEncoder().encode(save)
    let decoded = try JSONDecoder().decode(SaveData.self, from: data)
    #expect(decoded == save)
  }
}
