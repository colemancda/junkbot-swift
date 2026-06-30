// Translated from Lingo: cast_keynum_input.ls

class CastKeynumInput: LingoObject, @unchecked Sendable {
    // Original Lingo body: exitframe
    // ```lingo
    // on exitFrame me
    //   num = integer(member("keynum_input").text)
    //   if num > 15 then
    //     member("keynum_input").text = "15"
    //   else
    //     if num <= 0 then
    //       member("keynum_input").text = "0"
    //     end if
    //   end if
    //   glob[#keyrequired] = integer(member("keynum_input").text)
    // end
    // ```
    func exitFrame() {
        var num = Int(member("keynum_input")?.text ?? "") ?? 0
        if num > 15 {
            member("keynum_input")?.text = "15"
        } else {
            if num <= 0 {
                member("keynum_input")?.text = "0"
            }
        }
        Glob.shared["keyrequired"] = .int(Int(member("keynum_input")?.text ?? "") ?? 0)
    }
}
