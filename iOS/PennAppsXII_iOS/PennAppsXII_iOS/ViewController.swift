//
//  ViewController.swift
//  PennAppsXII_iOS
//
//  Created by Phillip Trent on 9/5/15.
//
//

import UIKit
import CoreBluetooth
class ViewController: UIViewController {
  
  var model: Model!
  
  @IBOutlet weak var numberLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    model = Model(presentationContext: self)
  }
  
  @IBAction func settings(sender: UIBarButtonItem) {
    if let settingsVC = storyboard?.instantiateViewControllerWithIdentifier("SettingsViewController") as? SettingsViewController {
      settingsVC.delegate = self
      presentViewController(settingsVC, animated: true, completion: {
        settingsVC.picker.selectRow(self.model.currentPeripherals.count - 1, inComponent: 0, animated: true)
      })
    }
  }

}

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  @IBOutlet weak var picker: UIPickerView!
  var delegate: ViewController!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    picker.delegate = self
  }
  
  func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    return "\(row + 1)"
  }
  
  func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    delegate.model.numberOfPeripherals = row + 1
  }
  
  func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return 10
  }
  
  func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
    return 1
  }
  
  @IBAction func done(sender: UIButton) {
    dismissViewControllerAnimated(true, completion: nil)
  }
  
}