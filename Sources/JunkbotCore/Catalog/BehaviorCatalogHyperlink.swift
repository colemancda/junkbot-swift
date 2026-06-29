// Translated from Lingo: behavior_catalog-hyperlink beh.ls

class BehaviorCatalogHyperlink {
    func hyperlinkClicked(_ data: String, range: Any) {
        glob.catalog.catalog_manager.clickLoad(data)
    }
}
