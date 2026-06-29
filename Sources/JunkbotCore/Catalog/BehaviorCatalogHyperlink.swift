// Translated from Lingo: behavior_catalog-hyperlink beh.ls

class BehaviorCatalogHyperlink {
    func hyperlinkClicked(_ data: String, range: LV) {
        glob.catalog.catalog_manager.clickLoad(data)
    }
}
