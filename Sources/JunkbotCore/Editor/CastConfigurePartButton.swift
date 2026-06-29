// Translated from Lingo: cast_configure part button.ls

class CastConfigurePartButton {
    func mouseUp() {
        glob.EDITOR.edit_manager.doConfigPart(member("part inspector field").text)
    }
}
