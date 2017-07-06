//
//  SpeakerCollectionViewCell.swift
//  Look Who's Talking
//
//  Created by Jen Person on 6/12/17.
//  Copyright © 2017 Team Chatty Kathy. All rights reserved.
//

import UIKit

class SpeakerCollectionViewCell: UICollectionViewCell {
    
    // MARK: Properties
    var allowEdit = true
    
    // MARK: Outlets
    @IBOutlet weak var speakerTextField: UITextField!
    @IBOutlet weak var speakerTimeLabel: UILabel!
    @IBOutlet weak var speakerLabel: UILabel!
    
    func populateCell(speaker: String, time: Float) {
        speakerTextField.backgroundColor = UIColor.clear
        //speakerTextField.text = speaker + " " + time.description
        speakerTimeLabel.text = time.description
        speakerLabel.text = speaker
    }
}

extension SpeakerCollectionViewCell: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        speakerLabel.text = textField.text
        textField.text = " "
        NotificationCenter.default.post(name: newSpeaker, object: nil)
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // disable textField when recording. You cannot change name in the middle of recording
        if isRecording == true {
            return false
        }
        return true
    }
}
