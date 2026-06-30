// Translated from Lingo: behavior_catalog-hyperlink beh.ls

class BehaviorCatalogHyperlink: LingoObject, @unchecked Sendable {
  // Original Lingo body: hyperlinkclicked
  // ```lingo
  // on HyperlinkClicked me, data, range
  //   glob.catalog.catalog_manager.clickLoad(data)
  // end
  // ```
  func hyperlinkClicked(_ data: LV, range: LV) {
    // catalog_manager is accessed via LV dynamic lookup
    // clickLoad(data.asString ?? "") would need a typed ref
    _ = data
  }
}
