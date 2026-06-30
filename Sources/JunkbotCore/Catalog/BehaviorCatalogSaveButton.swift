// Translated from Lingo: behavior_catalog save button beh.ls

class BehaviorCatalogSaveButton: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   global glob
  //   glob.catalog.catalog_manager.save()
  // end
  // ```
  func mouseUp() {
    glob.catalog.catalog_manager.save()
  }
}
