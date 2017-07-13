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
var audioStatus: AudioStatus = AudioStatus.Stopped

class RecordingViewController: UIViewController, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    
    // MARK: Properties
    var timer: Timer?
    var playTimer: Timer?
    var speakers: [String] = []
    var speakerTimes: [Float] = []
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var seconds: Float = 0.00
    var playSeconds: Float = 0.00
    let MAX_TIME: Float = 20.0
    var currentSpeakerTime: Float = 0.0
    var ref: DatabaseReference?
    var recordingsRef: DatabaseReference?
    
    var audioPlayer: AVAudioPlayer!
    
    // MARK: Outlets
    
    @IBOutlet weak var speakersCollectionView: UICollectionView!
    @IBOutlet weak var numSpeakers: UIStepper!
    @IBOutlet weak var numSpeakersLabel: UILabel!
    @IBOutlet weak var recordProgressView: UIProgressView!
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var playbackProgressView: UIProgressView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        
        recordingsRef = ref?.child("recordings")
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateSpeakers), name: newSpeaker, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let nc = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        
        nc.addObserver(self, selector: #selector(self.handleInterruption), name: NSNotification.Name.AVAudioSessionInterruption, object: session)
        nc.addObserver(self, selector: #selector(self.handleRouteChange), name: NSNotification.Name.AVAudioSessionRouteChange, object: session)
        
        configureView()
        setupRecorder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // remove observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // set up default speakers
    func configureView() {
        playbackProgressView.progress = 0
        audioStatus = .Stopped
        recordButton.isUserInteractionEnabled = false
        numSpeakers.minimumValue = 2
        numSpeakers.maximumValue = 5
        let currVal = Int(numSpeakers.value)
        updateNumSpeakers(val: currVal)
        grantRecordAccess()
        activateButton(button: playButton, activate: false)
    }
    
    @objc func updateSpeakers() {
        for i in 0..<speakers.count {
            let cell = speakersCollectionView.cellForItem(at: IndexPath(item: i, section: 0)) as! SpeakerCollectionViewCell
            if speakers[i] == " " {
                speakers[i] = cell.speakerLabel.text!
            }
            
        }
        updatePercentSpeakingTime()
    }
    
    func activateButton(button: UIButton, activate: Bool) {
        if activate {
            button.isUserInteractionEnabled = true
            button.tintColor = UIColor.blue
        } else {
            button.isUserInteractionEnabled = false
            button.tintColor = UIColor.lightGray
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
                        self.recordButton.isUserInteractionEnabled = true
                    } else {
                        // failed to record!
                    }
                }
            }
        } catch {
            // failed to record!
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func enableSpeakers(isEnabled: Bool) {
        isRecording = !isEnabled
    }
    
    func startRecording() {
        if appHasMicAccess == true {
            if audioStatus != .Playing {
                
                switch audioStatus {
                case .Stopped:
                    recordButton.setBackgroundImage(UIImage(named: "button-record1"), for: .normal)
                    record()
                case .Recording:
                    recordButton.setBackgroundImage(UIImage(named: "button-record"), for: .normal)
                    stopRecording()
                default:
                    break
                }
            }
        } else {
            recordButton.isEnabled = false
            let theAlert = UIAlertController(title: "Requires Microphone Access",
                                             message: "Go to Settings > Look Who's Talking > Allow Look Who's Talking to Access Microphone.\nSet switch to enable.",
                                             preferredStyle: UIAlertControllerStyle.alert)
            
            theAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.view?.window?.rootViewController?.present(theAlert, animated: true, completion:nil)
        }
    }
    
    @objc func recordTapped() {
        if audioStatus != .Recording{
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
    
    // MARK: IBActions
    
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
            speakerCell.percentSpeakerLabel.textColor = UIColor.black
        } else {
            speakerCell.speakerTimeLabel.textColor = UIColor.white
            speakerCell.speakerLabel.textColor = UIColor.white
            speakerCell.percentSpeakerLabel.textColor = UIColor.white
            speakerCell.backgroundColor = UIColor.blue
        }
    }
    
    @objc func updatePlaybackProgressView() {
        let length = audioPlayer.duration
        playSeconds+=1
        if playSeconds > Float(length) {
            playTimer?.invalidate()
            return
        }
        playbackProgressView.progress = 0
        self.playbackProgressView.progress = Float(playSeconds/Float(length))
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
            self.cleanUpViewAfterRecording()
            self.activateButton(button: self.playButton, activate: true)
        })
        
        let cancelButton = UIAlertAction(title: "Discard", style: .cancel, handler: { _ in
            self.audioRecorder.deleteRecording()
            // set all speaker counts to 0
            self.cleanUpViewAfterRecording()
        })
        
        alert.addAction(saveButton)
        alert.addAction(cancelButton)
        self.present(alert, animated: true, completion: nil)
    }
    
    func finishRecording(success: Bool) {
        audioRecorder?.stop()
        //audioRecorder = nil
        removeHighlighted(collectionView: speakersCollectionView)
        enableSpeakers(isEnabled: true)
        
        if success {
            confirmRecordAlert()
        } else {
            // recording failed :(
        }
        recordButton.setTitle("Record", for: .normal)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
        audioStatus = .Stopped
    }
    
    func cleanUpViewAfterRecording() {
        for i in 0..<self.speakers.count {
            self.speakerTimes[i] = 0.0
        }
        recordProgressView.progress = 0
        updateSpeakingTime()
        updatePercentSpeakingTime()
        seconds = 0.0
        currentSpeakerTime = 0.0
        recordLabel.text = seconds.description
        
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
    
    func totalSpeakingTime() -> Float {
        var totSpeakingTime: Float = 0.0
        for speakerTime in speakerTimes {
            print(speakerTime)
            totSpeakingTime += speakerTime
        }
        return totSpeakingTime
    }
    
    func updatePercentSpeakingTime() {
        let speakerTime = totalSpeakingTime()
        for i in 0..<speakers.count {
            let cell = speakersCollectionView.cellForItem(at: IndexPath(item: i, section: 0)) as! SpeakerCollectionViewCell
            let percent = Float((speakerTimes[i]/speakerTime)*100).description
            if percent != "nan" {
                cell.percentSpeakerLabel.text = Float((speakerTimes[i]/speakerTime)*100).description + "%"
            } else {
                cell.percentSpeakerLabel.text = "0%"
            }
        }
    }
    
    func updateSpeakingTime() {
        for i in 0..<speakers.count {
            let cell = speakersCollectionView.cellForItem(at: IndexPath(item: i, section: 0)) as! SpeakerCollectionViewCell
            cell.speakerTimeLabel.text = speakerTimes[i].description
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
            updatePercentSpeakingTime()
        }
    }
    
    @objc func setProgress() {
        seconds+=1
        // stop timer after certain interval
        if seconds > MAX_TIME {
            endTimer()
            seconds = 0.0
            // enable stepper when timer ends
            numSpeakers.isEnabled = true
            finishRecording(success: true)
            return
        }
        recordLabel.text = seconds.description
        recordProgressView.progress = Float(seconds/MAX_TIME)
    }
    @IBAction func playPressed(_ sender: UIButton) {
        if audioStatus != .Recording {
            
            switch audioStatus {
            case .Stopped:
                // clear timer
                playTimer?.invalidate()
                // reset speaker progress
                playbackProgressView.progress = Float(0.0)
                // disable adding or removing speakers. may need to change functionality later
                playTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updatePlaybackProgressView), userInfo: nil, repeats: true)
                play()
            case .Playing:
                stopPlayback()
            default:
                break
            }
        }
    }
    
    
    @IBAction func controlRecording(_ sender: UIButton) {
        // clear timer
        timer?.invalidate()
        // reset speaker progress
        recordProgressView.progress = Float(0.0)
        if audioStatus == .Stopped {
            // disable adding or removing speakers. may need to change functionality later
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.setProgress), userInfo: nil, repeats: true)
            startRecording()
        } else {
            seconds = 0.0
            // enable stepper when timer ends
            numSpeakers.isEnabled = true
            finishRecording(success: true)
            stopRecording()
        }
    }
    
    func setPlayButtonOn(flag: Bool) {
        if flag == true {
            playButton.setImage(UIImage(named: "ic_play_arrow"), for: .normal)
            playButton.tintColor = UIColor.black
        } else {
            playButton.setImage(UIImage(named: "ic_play_arrow"), for: .normal)
            playButton.tintColor = UIColor.red
        }
    }
    
    // MARK: Recording
    func setupRecorder() {
        let fileURL = getURLforMemo()
        
        let recordSettings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ] as [String : Any]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL as URL, settings: recordSettings as [String : AnyObject])
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
        } catch {
            print("Error creating audioRecorder.")
        }
    }
    
    func record() {
        audioRecorder?.record()
        audioStatus = .Recording
        recordButton.setImage(#imageLiteral(resourceName: "ic_stop"), for: .normal)
        activateButton(button: playButton, activate: false)
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        recordButton.setImage(#imageLiteral(resourceName: "ic_fiber_manual_record"), for: .normal)
        audioStatus = .Stopped
    }
    
    // MARK: Playback
    func  play() {
        let fileURL = getURLforMemo()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL as URL)
            audioPlayer.delegate = self
            if audioPlayer.duration > 0.0 {
                setPlayButtonOn(flag: true)
                audioPlayer.play()
                updatePlaybackProgressView()
                audioStatus = .Playing
                playButton.setImage(#imageLiteral(resourceName: "ic_stop"), for: .normal)
            }
        } catch {
            print("Error loading audioPlayer.")
        }
    }
    
    func stopPlayback() {
        audioPlayer.stop()
        setPlayButtonOn(flag: false)
        audioStatus = .Stopped
        playButton.setImage(#imageLiteral(resourceName: "ic_play_arrow"), for: .normal)
    }
    
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        setPlayButtonOn(flag: false)
        audioStatus = .Stopped
    }
    
    
    // MARK: Notifications
    @objc func handleInterruption(notification: NSNotification) {
        if let info = notification.userInfo {
            let type = AVAudioSessionInterruptionType(rawValue: info[AVAudioSessionInterruptionTypeKey] as! UInt)
            if type == .began {
                if audioStatus == .Playing {
                    stopPlayback()
                } else if audioStatus == .Recording {
                    stopRecording()
                }
            } else {
                let options = AVAudioSessionInterruptionOptions(rawValue: info[AVAudioSessionInterruptionOptionKey] as! UInt)
                
                if options == .shouldResume {
                    // Do something here...
                }
            }
        }
    }
    
    @objc func handleRouteChange(notification: NSNotification) {
        if let info = notification.userInfo {
            
            let reason = AVAudioSessionRouteChangeReason(rawValue: info[AVAudioSessionRouteChangeReasonKey] as! UInt)
            if reason == .oldDeviceUnavailable {
                let previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
                let previousOutput = previousRoute!.outputs.first!
                if previousOutput.portType == AVAudioSessionPortHeadphones {
                    if audioStatus == .Playing {
                        stopPlayback()
                    } else if audioStatus == .Recording {
                        stopRecording()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func getURLforMemo() -> NSURL {
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "/TempMemo.caf"
        
        return NSURL.fileURL(withPath: filePath) as NSURL
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


