//
//  RecordingViewController.swift
//  Look Who's Talking
//
//  Created by Jen Person on 6/9/17.
//  Copyright © 2017 Team Chatty Kathy. All rights reserved.
//

import UIKit
import AVFoundation
import FirebaseDatabase

let newSpeaker = NSNotification.Name("newSpeaker")
var isRecording = false

class RecordingViewController: UIViewController, AVAudioRecorderDelegate {
    
    // MARK: Properties
    var timer: Timer?
    var speakers: [String] = []
    var speakerTimes: [Float] = []
    var selectedCell: IndexPath?// = IndexPath(item: 0, section: 0)
    var numSpeakersVal = 1
    let components = [1, 2, 3, 4]
    let pickerVC = UIViewController()
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder?
    var seconds: Float = 0.00
    let MAX_TIME: Float = 20.0
    var currentSpeakerTime: Float = 0.0
    var ref: DatabaseReference?
    var recordingsRef: DatabaseReference?
    
    // MARK: Outlets
    
    @IBOutlet weak var speakersCollectionView: UICollectionView!
    @IBOutlet weak var numSpeakers: UIStepper!
    @IBOutlet weak var numSpeakersLabel: UILabel!
    @IBOutlet weak var recordProgressView: UIProgressView!
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        recordingsRef = ref?.child("recordings")
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateSpeakers), name: newSpeaker, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
    }
    
    // set up default speakers
    func configureView() {
        numSpeakers.minimumValue = 2
        numSpeakers.maximumValue = 5
        let currVal = Int(numSpeakers.value)
        updateNumSpeakers(val: currVal)
    }
    
    @objc func updateSpeakers() {
        for i in 0..<speakers.count {
            let cell = speakersCollectionView.cellForItem(at: IndexPath(item: i, section: 0)) as! SpeakerCollectionViewCell
            if speakers[i] == " " {
                speakers[i] = cell.speakerLabel.text!
            }
        }
    }
    
    func grantRecordAccess() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        // decide what to do here. enable record button?
                    } else {
                        // failed to record!
                    }
                }
            }
        } catch {
            // failed to record!
        }
    }
    
  /*  func loadRecordingUI() {
        recordButton = UIButton(frame: CGRect(x: 64, y: 64, width: 128, height: 64))
        recordButton.setTitle("Tap to Record", for: .normal)
        recordButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.title1)
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        view.addSubview(recordButton)
    }*/
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func enableSpeakers(isEnabled: Bool) {
        isRecording = !isEnabled
    }
    
    func startRecording() {
        enableSpeakers(isEnabled: false)
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            finishRecording(success: false)
        }
    }
    
    @objc func recordTapped() {
        if audioRecorder == nil {
            recordButton.setTitle("Stop", for: .normal)
            startRecording()
        } else {
            finishRecording(success: true)
        }
    }
    
    func updateNumSpeakers(val: Int) {
        numSpeakersLabel.text = val.description
        // if adding speakers
        if val > speakers.count {
            for _ in speakers.count..<val {
                speakers.append(" ")
                speakerTimes.append(0.0)
            }
        } else {
            // if removing speakers
            for i in (val..<speakers.count).reversed() {
                speakers.remove(at: i)
                speakerTimes.remove(at: i)
            }
        }
        speakersCollectionView.reloadData()
    }
    
    @IBAction func numSpeakerValueChanged(_ sender: Any) {
        let stepper = sender as! UIStepper
        let currVal = Int(stepper.value)
        updateNumSpeakers(val: currVal)
    }
    
    func highlightCell(speakerCell: SpeakerCollectionViewCell, isHighlighted: Bool) {
        if isHighlighted {
            speakerCell.backgroundColor = UIColor.white
            speakerCell.speakerTimeLabel.textColor = UIColor.black
            speakerCell.speakerLabel.textColor = UIColor.black
        } else {
            speakerCell.speakerTimeLabel.textColor = UIColor.white
            speakerCell.speakerLabel.textColor = UIColor.white
            speakerCell.backgroundColor = UIColor.blue
        }
    }
    
    func confirmRecordAlert() {
        let alert = UIAlertController(title: "Recording Complete", message: "Save Recording?", preferredStyle: .alert)
        
        let saveButton = UIAlertAction(title: "Save", style: .default, handler: { _ in
            // upload results to database
            var currentRecording = [String:String]()
            for i in 0..<self.speakers.count {
                currentRecording[self.speakers[i]] = self.speakerTimes[i].description
            }
            self.recordingsRef?.childByAutoId().setValue(currentRecording)
        })
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(saveButton)
        alert.addAction(cancelButton)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func finishRecording(success: Bool) {
        audioRecorder?.stop()
        audioRecorder = nil
        removeHighlighted(collectionView: speakersCollectionView)
        enableSpeakers(isEnabled: true)
        
        if success {
            confirmRecordAlert()
            
        } else {
            // recording failed :(
        }
        recordButton.setTitle("Record", for: .normal)
        recordProgressView.progress = 0.0
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    func endTimer() {
        timer?.invalidate()
    }
    
    func removeHighlighted(collectionView: UICollectionView) {
        for i in 0..<speakers.count {
            let cell = collectionView.cellForItem(at: IndexPath(item: i, section: 0)) as! SpeakerCollectionViewCell
            if cell.backgroundColor == UIColor.blue {
                let totalTime = seconds - currentSpeakerTime
                // why is this negative??
                speakerTimes[i] += totalTime
                collectionView.reloadItems(at: [IndexPath(item: i, section: 0)])
                highlightCell(speakerCell: cell, isHighlighted: true)
            }
        }
    }
    
    func handleSelectedSpeaker(indexPath: IndexPath, collectionView: UICollectionView) {
        if let audioRecorder = audioRecorder, audioRecorder.isRecording {
            var isCurrentlyHighlighted = false
            let speakerCell = collectionView.cellForItem(at: indexPath) as! SpeakerCollectionViewCell
            for i in 0..<speakers.count {
                let cell = collectionView.cellForItem(at: IndexPath(item: i, section: 0)) as! SpeakerCollectionViewCell
                if cell.backgroundColor == UIColor.blue {
                    let totalTime = seconds - currentSpeakerTime
                    speakerTimes[i] += totalTime
                    collectionView.reloadItems(at: [IndexPath(item: i, section: 0)])
                    if IndexPath(item: i, section: 0) == indexPath {
                        isCurrentlyHighlighted = true
                    }
                    highlightCell(speakerCell: cell, isHighlighted: true)
                }
            }
            // highlight currently selected speaker if not previously selected speaker
            if !isCurrentlyHighlighted {
                highlightCell(speakerCell: speakerCell, isHighlighted: false)
            }
            currentSpeakerTime = seconds
        }
    }
    
    @objc func setProgress() {
        seconds+=1
        // stop timer after certain interval
        if seconds > MAX_TIME {
            endTimer()
            return
        }
        recordLabel.text = seconds.description
        recordProgressView.progress = Float(seconds/MAX_TIME)
        print(recordProgressView.progress)
    }
    
    
    @IBAction func controlRecording(_ sender: UIButton) {
        // clear timer
        timer?.invalidate()
        // reset speaker progress
        recordProgressView.progress = 0
        if audioRecorder == nil {
            // disable adding or removing speakers. may need to change functionality later
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.setProgress), userInfo: nil, repeats: true)
            startRecording()
        } else {
            seconds = 0.0
            // enable stepper when timer ends
            numSpeakers.isEnabled = true
            finishRecording(success: true)
        }
    }
}

extension RecordingViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    @available(iOS 6.0, *)
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return speakers.count
    }
    
    @available(iOS 6.0, *)
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let speakerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Speaker", for: indexPath) as! SpeakerCollectionViewCell
        speakerCell.populateCell(speaker: speakers[indexPath.item], time: speakerTimes[indexPath.item])
        return speakerCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleSelectedSpeaker(indexPath: indexPath, collectionView: collectionView)
    }
}


