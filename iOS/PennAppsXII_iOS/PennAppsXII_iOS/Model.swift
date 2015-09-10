//
//  Model.swift
//  PennAppsXII_iOS
//
//  Created by Phillip Trent on 9/5/15.
//
//

import Foundation
import UIKit
import CoreBluetooth
import CoreMotion

enum ConnectionMode:Int {
  case None
  case PinIO
  case UART
  case Info
  case Controller
  case DFU
}

typealias PeripheralInfo = (peripheral: CBPeripheral!, characteristic: CBCharacteristic!, RSSI: NSNumber!)

public class Model: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  
  ///The central manager for bluetooth interactions
  private var centralManager: CBCentralManager!
  
  ///Motion Manager
  private let motionManager: CMMotionManager!
  
  ///The view controller on which to display errors and alerts
  private let presentationContext: ViewController
  
  ///Peripheral that we're connected to
  var currentPeripherals: [PeripheralInfo] = [] {
    didSet {
      presentationContext.numberLabel.text = "\(currentPeripherals.count)"
    }
  }
  
  ///number of bluetooth peripherals that the user chooses
  var numberOfPeripherals: Int = 1 {
    willSet {
      if newValue < numberOfPeripherals {
        currentPeripherals = []
      }
    }
    didSet {
      centralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
  }
  
  /**
  Designated initializer for the `Model` class
  
  -parameter presentationContext The view controller on which to display any errors that arise
  */
  init(presentationContext: ViewController) {
    print(__FUNCTION__)
    self.presentationContext = presentationContext
    motionManager = CMMotionManager()
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: nil)
    motionManager.accelerometerUpdateInterval = 1
    motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue()) { (data, error) -> Void in
      for object in self.currentPeripherals {
        object.peripheral.readRSSI()
      }
    }
  }
  
  //MARK: - Central Manager Delegate
  
  public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
    print(__FUNCTION__)
    peripheral.discoverServices(nil)
  }
  
  public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
    
    let newPeripherals = currentPeripherals.filter({ $0.peripheral.identifier != peripheral.identifier })
    currentPeripherals = newPeripherals
    
    print(__FUNCTION__)
    central.stopScan()
    central.scanForPeripheralsWithServices(nil, options: nil)
  }
  
  public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
    print("Did Discover AdvertisementData: \(advertisementData) \n RSSI: \(RSSI)")
    if advertisementData[CBAdvertisementDataLocalNameKey] as? String == "Adafruit Bluefruit LE" {
      peripheral.delegate = self
      currentPeripherals.append((peripheral, nil, RSSI))
      central.connectPeripheral(peripheral,
        options: nil)
      print("tried to connect")
    }
    
    if currentPeripherals.count == numberOfPeripherals {
      central.stopScan()
    }
  }
  
  public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
    print(__FUNCTION__)
    
    if let error = error {
      let alert = Alert(presentationContext: self.presentationContext)
      alert.title = "Failed to Connect"
      alert.message =
        "It looks like there was an issue connecting to the peripheral device. Error Description: \(error.localizedDescription)." +
        (error.localizedFailureReason != nil ? " Error Failure Reason: \(error.localizedFailureReason)." : "") +
        (error.localizedRecoverySuggestion != nil ? " Error Recovery Suggestion: \(error.localizedRecoverySuggestion)." : "")
      alert.present()
      return
    }
  }
  
  public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
    print(__FUNCTION__)
  }
  
  public func centralManagerDidUpdateState(central: CBCentralManager) {
    switch central.state {
    case .PoweredOn :
      //Bluetooth is currently powered on and available to use.
      print("State is PoweredOn")
      central.scanForPeripheralsWithServices(nil, options: nil)
      break
    case .PoweredOff :
      //Bluetooth is currently powered off.
      let alert = Alert(presentationContext: self.presentationContext)
      alert.title = "Bluetooth Off"
      alert.message = "Please turn your phone's bluetooth on."
      alert.present()
      break
    case .Resetting, .Unknown:
      //The connection with the system service was momentarily lost or is unknown; an update is imminent.
      break
    case .Unauthorized :
      //The app is not authorized to use Bluetooth low energy.
      let alert = Alert(presentationContext: self.presentationContext)
      alert.title = "Bluetooth Inaccessible"
      alert.message = "Unfortunately, this app does not have access to your bluetooth."
      alert.present()
      break
    case .Unsupported :
      //The platform does not support Bluetooth low energy.
      let alert = Alert(presentationContext: self.presentationContext)
      alert.title = "Bluetooth Inaccessible"
      alert.message = "It looks like this device is not equipped with bluetooth technology. I'm so sorry."
      alert.present()
      break
    }
  }
  
  //MARK: - Peripheral Delegate
  
  ///All the write channels for the peripherals
  public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
    if let services = peripheral.services {
      for service in services {
        peripheral.discoverCharacteristics(nil, forService: service)
      }
    }
  }
  
  public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
    peripheral.readRSSI()
    let txCharacteristics = currentPeripherals.map({ $0.characteristic })
    //make sure the characteristics exist
    if let characteristics = service.characteristics {
      
      //if we know what the characteristic is
      for characteristic in characteristics where knownUUIDs.contains(characteristic.UUID) {
        
        //and the characteristic is a write channel
        if characteristic.UUID == txCharacteristicUUID() {
          
          //check if the txCharacteristics already sees the current characteristic
          let filteredArray = txCharacteristics.filter {
            if $0 != nil  {
              return $0.service.peripheral.identifier == characteristic.service.peripheral.identifier
            }
            return false
          }
          if filteredArray.count == 0 {
            //if not, find the corresponding peripheral and put it in the currentPeripherals
            for i in 0..<currentPeripherals.count where currentPeripherals[i].peripheral.identifier == characteristic.service.peripheral.identifier {
              currentPeripherals[i].characteristic = characteristic
            }
          }
        }
      }
    }
  }

  public func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
    var newPeripherals = currentPeripherals.map{
      return $0.peripheral.identifier == peripheral.identifier ? (peripheral, $0.characteristic, RSSI) : $0
    }
    newPeripherals.sortInPlace({ $0.RSSI.doubleValue > $1.RSSI.doubleValue + 5 })
    currentPeripherals = newPeripherals
    print(currentPeripherals.map({$0.RSSI.doubleValue}))
    writeString("UNMUTE")
  }
  
  ///Writes a specific string to the device
  func writeString(string:NSString){
    
    //Send string to peripheral
    
    let data = NSData(bytes: string.UTF8String, length: string.length)
    let muteData = NSData(bytes: "MUTE".UTF8String, length: string.length)
    let txCharacteristics = currentPeripherals.map({ $0.characteristic })
    for i in 0..<txCharacteristics.count {
      if i == 0 {
        writeRawData(data, toCharacteristic: txCharacteristics[i])
      } else {
        writeRawData(muteData, toCharacteristic: txCharacteristics[i])
      }
    }
  }
  
  ///Writes raw data to the device
  func writeRawData(data:NSData, toCharacteristic txCharacteristic: CBCharacteristic!) {
    //Send data to peripheral
    
    if (txCharacteristic == nil){
      print("Unable to write data without txcharacteristic")
      return
    }
    
    var writeType:CBCharacteristicWriteType
    
    if (txCharacteristic!.properties.rawValue & CBCharacteristicProperties.WriteWithoutResponse.rawValue) != 0 {
      
      writeType = CBCharacteristicWriteType.WithoutResponse
      
    }
      
    else if ((txCharacteristic!.properties.rawValue & CBCharacteristicProperties.Write.rawValue) != 0){
      
      writeType = CBCharacteristicWriteType.WithResponse
    }
      
    else{
      print("Unable to write data without characteristic write property")
      return
    }
    
    //TODO: Test packetization
    
    //send data in lengths of <= 20 bytes
    let dataLength = data.length
    let limit = 20
    
    //Below limit, send as-is
    if dataLength <= limit {
      txCharacteristic.service.peripheral.writeValue(data, forCharacteristic: txCharacteristic, type: writeType)
    }
      
      //Above limit, send in lengths <= 20 bytes
    else {
      
      var len = limit
      var loc = 0
      var idx = 0 //for debug
      
      while loc < dataLength {
        
        let rmdr = dataLength - loc
        if rmdr <= len {
          len = rmdr
        }
        
        let range = NSMakeRange(loc, len)
        var newBytes = [UInt8](count: len, repeatedValue: 0)
        data.getBytes(&newBytes, range: range)
        let newData = NSData(bytes: newBytes, length: len)
        //                    println("\(self.classForCoder.description()) writeRawData : packet_\(idx) : \(newData.hexRepresentationWithSpaces(true))")
        txCharacteristic.service.peripheral.writeValue(newData, forCharacteristic: txCharacteristic, type: writeType)
        
        loc += len
        idx += 1
      }
    }
    
  }
  
  //MARK: - Alert Class
  
  ///Class to easily setup and display an alert
  private class Alert {
    
    ///The context with which to display the alert
    let presentationContext: UIViewController
    
    var title: String = "Error"
    var message: String = "There was an issue."
    
    ///Button actions for the alert
    var actions: [UIAlertAction]? = nil
    
    init(presentationContext: UIViewController) {
      self.presentationContext = presentationContext
    }
    
    ///Present the alert with the current title and message
    func present() {
      let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
      if let allActions = actions {
        allActions.map { alertController.addAction($0) }
      } else {
        alertController.addAction(UIAlertAction(title: "Okay", style: .Cancel, handler: nil))
      }
      presentationContext.presentViewController(alertController, animated: true, completion: nil)
    }
    
  }
}
