// Translated from Lingo: cast_configure part button.ls

class CastConfigurePartButton: LingoObject, @unchecked Sendable {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp
    //   global glob
    //   glob.EDITOR.edit_manager.doConfigPart(member("part inspector field").text)
    // end
    // ```
    func mouseUp() {
        glob.EDITOR.edit_manager.doConfigPart(.string(member("part inspector field")?.text ?? ""))
    }
}
