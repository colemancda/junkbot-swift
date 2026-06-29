// Translated from Lingo: cast_keynum_input.ls

class CastKeynumInput {
    func exitFrame() {
        var num = Int(member("keynum_input").text) ?? 0
        if num > 15 {
            member("keynum_input").text = "15"
        } else {
            if num <= 0 {
                member("keynum_input").text = "0"
            }
        }
        Glob.shared["keyrequired"] = .int(Int(member("keynum_input").text) ?? 0)
    }
}
