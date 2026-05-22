//
//  Remove filename tag.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-21.
//

import Foundation



extension Substring {
    
    /// Sometimes, the bot will include a filename tag at the start of its message. This removes it.
    ///
    /// Here's a real example:
    /// > [img-0]Northstar✨ 칠성들 (@KyNorthstar):
    /// > Image attachment: The image shows a man wearing glasses and holding up a yellow highlighter. The text on the screen reads "This makes everyone dumb", indicating that the man is making a statement about the use of highlighters by others.
    ///
    /// - Returns: The message without the initial filename tag, if'n it has one
    func removingFilenameTag() -> Substring {
        isolate(by: /^(\[.+?\])?(?<keep>(.|\n)+)$/, keeping: \.keep)
    }
}
