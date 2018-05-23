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

 
    override func viewDidLoad() {
        super.viewDidLoad()
        let a = SNDocx()
         a.printAA()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

