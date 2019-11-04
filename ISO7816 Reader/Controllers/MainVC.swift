//
//  MainVC.swift
//  ISO7816 Reader
//
//  Created by Stephen Caudle on 11/4/19.
//  Copyright © 2019 Mulum. All rights reserved.
//

import UIKit
import CoreNFC

class MainVC: UIViewController, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession!
    
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var read: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func onReadPressed(_ sender: Any) {
        self.session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self)
        self.session?.alertMessage = "Hold your phone near reader"
        self.session?.begin()
        
        self.status.text = "Reading..."
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            let validErrors = [.readerSessionInvalidationErrorFirstNDEFTagRead,
                               .readerSessionInvalidationErrorUserCanceled,
                               .readerSessionInvalidationErrorSessionTimeout] as [NFCReaderError.Code]
            
            if !validErrors.contains(readerError.code) {
                print("tagReaderSession error: \(error.localizedDescription)")
                
                let alertController = UIAlertController(
                    title: "Tag Error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                
                DispatchQueue.main.async {
                    self.done()
                }
                
                return
            }
        }
        
        DispatchQueue.main.async {
            self.done()
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        let nfcTag = tags.first!
        var statusText = "Idle"
        
        if case let .iso7816(tag) = nfcTag {
            session.connect(to: nfcTag) { (error: Error?) in
                let myAPDU = NFCISO7816APDU(instructionClass:0xF0, instructionCode:0x0D, p1Parameter:0x00, p2Parameter:0x00, data: Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]), expectedResponseLength: 7)
                tag.sendCommand(apdu: myAPDU) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
                    print("sendCommand")
                    let status = String(format:"%02X%02X", sw1, sw2)
                    statusText = "Response: \(status)"
                    
                    guard error == nil && sw1 == 0x90 && sw2 == 0x00 else {
                        print("error sending tag command: error: \(error.debugDescription) status: \(status)")
                        session.invalidate(errorMessage: "Application failure")

                        DispatchQueue.main.async {
                            self.done(statusText)
                        }
                        
                        return
                    }

                    print("tag command: status: \(status)) data: \(response.toHexString())")
                    session.alertMessage = "Success!"
                    session.invalidate()
                }
            }
        } else {
            session.invalidate(errorMessage: "Invalid tag")
        }
        
        DispatchQueue.main.async {
            self.done(statusText)
        }
    }

    private func done(_ status: String = "Idle") {
        self.status.text = status
    }
}
