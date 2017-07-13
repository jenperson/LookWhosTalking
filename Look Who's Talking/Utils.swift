
//
//  Utils.swift
//  Look Who's Talking
//
//  Added by Jen Person on 6/9/17. (Created by Michael Briscoe on 12/14/15.)
//  Copyright © 2017 Team Chatty Kathy. All rights reserved.
//

import Foundation

var appHasMicAccess = false

enum AudioStatus: Int, CustomStringConvertible {
    case Stopped = 0,
    Playing,
    Recording
    
    var audioName: String {
        let audioNames = [
            "Audio: Stopped",
            "Audio:Playing",
            "Audio:Recording"]
        return audioNames[rawValue]
    }
    
    var description: String {
        return audioName
    }
}

