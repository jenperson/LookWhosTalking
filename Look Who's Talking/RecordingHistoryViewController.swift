//
//  RecordingHistoryViewController.swift
//  Look Who's Talking
//
//  Created by Jen Person on 7/12/17.
//  Copyright © 2017 Team Chatty Kathy. All rights reserved.
//

import UIKit
import Firebase

class RecordingHistoryViewController: UIViewController {
    
    var ref: DatabaseReference!
    var recordingRef: DatabaseReference!
    var curruser = "testUser"
    var recordings = [DataSnapshot]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = Database.database().reference()
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension RecordingViewController: UITableViewDelegate, UITableViewDataSource {
    @available(iOS 2.0, *)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    @available(iOS 2.0, *)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.cellForRow(at: indexPath) as! RecordingHistoryTableViewCell
        
        return cell
    }
    
    
}

// MARK: Database handle

extension RecordingHistoryViewController {
    
    func configureDatabase() {
        recordingRef = ref?.child(curruser)
        recordingRef?.observe(.childAdded, with: { snapshot in
            self.recordings.append(snapshot)
        })
    }
}
