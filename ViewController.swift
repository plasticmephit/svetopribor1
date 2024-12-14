//
//  ViewController.swift
//  svetopribor
//
//  Created by Maksimilian on 5.02.23.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    var selectedDev: CBPeripheral? = nil
    var batteryPeripheral: CBPeripheral? = nil
    var centralManager: CBCentralManager!
    var devices: [CBPeripheral] = []
    var tableView: UITableView!
    var textField: UITextField!
    var writeChar:CBCharacteristic?
    var readChar:CBCharacteristic?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = UITableView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: view.bounds.height - 80), style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        textField = UITextField(frame: CGRect(x: 20, y: 60, width: view.bounds.width - 40, height: 40))
        textField.placeholder = "Введите строку"
        textField.borderStyle = .roundedRect
        textField.delegate = self
        view.addSubview(textField)
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth не включен")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name {
            devices.append(peripheral)
            tableView.reloadData()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown Error")")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.discoverCharacteristics(nil, for: peripheral.services![0])
        batteryPeripheral = peripheral
        if let services = peripheral.services {
            for service in services {
                print("Discovered service: \(service)")
                let data = textField.text!.data(using: .utf8)
            }
        } else {
            print("No services found on the peripheral")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(String(describing: error))")
            return
        }
        
        for characteristic in service.characteristics! {
            print("Discovered characteristic: \(characteristic.uuid)")
            
            // Check if the characteristic supports notify
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Check if the characteristic supports write
            if characteristic.properties.contains(.write) {
               
            
                 
//                        peripheral.writeValue(data, for: characteristic, type: .withResponse)
                        writeChar = characteristic
                let messageToSend = "a"
                sendString(toPeripheral: selectedDev!, message: messageToSend)
                }else{
                    readChar = characteristic
                
            }
            
            // Check if the characteristic supports read
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            print("Successfully wrote value for characteristic \(characteristic.uuid)")
            peripheral.readValue(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        
        if let value = characteristic.value, let responseString = String(data: value, encoding: .utf8) {
            print("Received response: \(responseString)")
            if responseString == "\0"{
                return
            }
            if responseString == "DEVICE_ALREADY_CONNE"{
                sendString(toPeripheral: selectedDev!, message: "d")
                return
            }
            if responseString == "CONNECT_OK\0"{
               sendString(toPeripheral: selectedDev!, message: "d")
                return
           }
            
            if responseString == "AUDIO_START_OK\0" || responseString == "AUDIO_START_OK"{
//                sendString(toPeripheral: selectedDev!, message: "b")
                centralManager.cancelPeripheralConnection(selectedDev!)
                
            }
            
            if responseString == ""{
              
            }
        } else {
            print("No value received or unable to decode data")
        }
    }

    func sendString(toPeripheral peripheral: CBPeripheral, message: String) {
       
        let message = message + "12:12:12:12:12:12"
                            if let data = message.data(using: .utf8) {
                                selectedDev!.writeValue(data, for: writeChar!, type: .withResponse)
                              
                            }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedDev = devices[indexPath.row]
        
        centralManager.connect(selectedDev!, options: nil)
      
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let device = devices[indexPath.row]
        cell.textLabel?.text = device.name
        cell.detailTextLabel?.text = device.name
        return cell
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
