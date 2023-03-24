//
//  BLEController.swift
//  ble_Camera
//
//  Created by Peter Rogers on 26/02/2022.
//



import Foundation
import UIKit
import CoreBluetooth

final class BLEController: NSObject, CBCentralManagerDelegate,  CBPeripheralDelegate{
    
    
    private var hasUpdated = true
    private var token: NSKeyValueObservation?
    var characteristicDidUpdateValue: ((Bool, Data?) -> Void)?
    var connectionChanged: ((connectionStatus) -> Void)?
    var arduinoData: ((Float) -> Void)?
    var connecting = false
    private var central: CBCentralManager?
    private var myPeripheral: CBPeripheral?
    private var mainCharacteristic:CBCharacteristic? = nil
    private let bleService = "FFE0"
    private let bleCharacteristic = "FFE1"
    private var timeoutTimer:Timer?
   
    
    
    
   
    
    func sendData(message:Int){
        print("d")
        if central != nil{
            if let p = myPeripheral{
                if let mc = mainCharacteristic{
                    
                    if(p.state == .connected){
                        
                            var s:String?
                            s = "\(message)>"
                            if let dataToSend = s?.data(using: String.Encoding.utf8){
                                
                                print(s ?? "none")
                                p.writeValue(dataToSend, for:mc, type: CBCharacteristicWriteType.withResponse)
                            }
                                
                            
                    }
                }
            }else{
                // print("no peripheral connected")
            }
        }else{
            //  print("no central connection")
        }
       
    }
    
    
    
    
    
    func isConnected()->Bool{
        
        if let p = myPeripheral{
            if(p.state == .disconnected || p.state == .disconnecting){
                return false
                
            }else{
                return true
            }
            
        }
        return false
    }
    
    
    func connect(){
        central = CBCentralManager(delegate: self, queue: nil)
        hasUpdated = true
       
        
        
    }
    
    func disconnect(){
        //  if(myPeripheral.)
        connecting = false
        if let c = central{
            if let p = myPeripheral{
                
                c.cancelPeripheralConnection(p)
            }
        }
        hasUpdated = true
    }
    
    
    
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        // /**
        if central.state != .poweredOn {
            // print("Central is not powered on")
            self.connectionChanged?((connectionStatus.unauthorized))
            
        } else {
            connecting = true
            self.connectionChanged?(connectionStatus.connecting)
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                //timer.invalidate()
                self.connectionChanged?(connectionStatus.disconnected)
                self.central?.stopScan()
                self.connecting = false
                // print("timeout")
            }
            // print("Central scanning for", bleService);
            central.scanForPeripherals(withServices: [ CBUUID.init(string: "FFE0")],
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
        // */
        
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // We've found it so stop scan
        central.stopScan()
        timeoutTimer?.invalidate()
        // Copy the peripheral instance
        peripheral.delegate = self
        
        if let c = self.central{
            c.connect(peripheral, options: nil)
        }
        self.myPeripheral = peripheral
        token = peripheral.observe(\.state){ [weak self] object, change in
            var cState = connectionStatus.disconnected
            if(object.state == .connecting){
                cState = .connecting
            }
            if(object.state == .connected){
                self?.connecting = false
                cState = .connected
            }
            if(object.state == .disconnecting){
                self?.connecting = false
                cState = .disconnecting
            }
            if(object.state == .disconnected){
                self?.connecting = false
                cState = .disconnected
            }
            
            self?.connectionChanged?((cState))
        }
        
    }
    
    // The handler if we do connect succesfully
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == self.myPeripheral {
            // print("Board found")
            peripheral.delegate = self
            peripheral.discoverServices(nil)
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid.uuidString == bleCharacteristic}) else { return }
        peripheral.setNotifyValue(true, for: characteristic)
        mainCharacteristic = characteristic
    }
    
    // Handles discovery event
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid.uuidString == bleService {
                    // print("Bluno Found")
                    //Now kick off discovery of characteristics
                    peripheral.discoverCharacteristics(nil, for: service)
                    
                    return
                }
            }
        }
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        
        hasUpdated = true
        let data = characteristic.value!
       // print(data)
        let dataString = String(data: data, encoding: String.Encoding.utf8)
       // print(dataString)
        let myarray = dataString!.components(separatedBy: ">")
       // print(myarray[0])
        self.arduinoData?((Float(myarray[0]) ?? 0.0))
        
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?){
        // print("from peripheral output")
        hasUpdated = true
    }
}

enum connectionStatus {
    case connecting
    case connected
    case disconnected
    case previewing
    case disconnecting
    case preview
    case unauthorized
}
