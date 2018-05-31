//
//  ViewController.swift
//  SNDocx
//
//  Created by ahmedAlmasri on 05/23/2018.
//  Copyright (c) 2018 ahmedAlmasri. All rights reserved.
//

import UIKit
import SNDocx

class ViewController: UIViewController {

 
    @IBOutlet weak var myTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let originalFileURL = Bundle.main.url(forResource: "Test", withExtension: "docx") else {
            print("file not found :( ")
            return
        }
        
        let result = SNDocx.shared.getText(fileUrl: originalFileURL)
        myTextView.text = result
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

