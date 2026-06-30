// Translated from Lingo: behavior_catalog-hyperlink beh.ls

class BehaviorCatalogHyperlink {
    func hyperlinkClicked(_ data: LV, range: LV) {
        // catalog_manager is accessed via LV dynamic lookup
        // clickLoad(data.asString ?? "") would need a typed ref
        _ = data
    }
}
