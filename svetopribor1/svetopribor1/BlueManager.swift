import CoreBluetooth
import UIKit

class BluetoothManager: NSObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()
    
    var selectedDev: CBPeripheral? = nil
    var batteryPeripheral: CBPeripheral? = nil
    var centralManager: CBCentralManager!
    var devices: [CBPeripheral] = []
    var writeChar: CBCharacteristic?
    var readChar: CBCharacteristic?
    var peripheralManager: CBPeripheralManager?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth не включен")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.starts(with: "BY"), !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            devices.append(peripheral)
            NotificationCenter.default.post(name: NSNotification.Name("didDiscoverPeripheral"), object: nil)
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
        peripheral.discoverCharacteristics(nil, for: peripheral.services!.first!)
        batteryPeripheral = peripheral
        if let services = peripheral.services {
            for service in services {
                print("Discovered service: \(service)")
                let data = "Some Data".data(using: .utf8)
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
        selectedDev = peripheral
        for characteristic in service.characteristics! {
            print("Discovered characteristic: \(characteristic.uuid)")
            
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            if characteristic.properties.contains(.write) {
                writeChar = characteristic
                sendString(toPeripheral: selectedDev!, message: "a")
            } else {
                readChar = characteristic
            }
            
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
            DispatchQueue.main.async {
                self.showAlert(response: responseString)
            }
        } else {
            print("No value received or unable to decode data")
        }
    }

    private func showAlert(response: String) {
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            let alert = UIAlertController(title: "Ответ", message: response, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            topController.present(alert, animated: true, completion: nil)
        }
    }

    func sendString(toPeripheral peripheral: CBPeripheral, message: String) {
        selectedDev = peripheral
       
        let fullMessage = message + convertUUIDTo12Format(peripheral.identifier)
        if let data = fullMessage.data(using: .utf8) {
            selectedDev?.writeValue(data, for: writeChar!, type: .withResponse)
        }
    }

    private func convertUUIDTo12Format(_ uuid: UUID) -> String {
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        var result = ""
        for (index, char) in uuidString.enumerated() {
            result.append(char)
            if index % 2 == 1 && index < 11 {
                result.append(":")
            }
        }
        return result
    }

    // Методы CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("Peripheral manager is powered on")
        } else {
            print("Peripheral manager is not powered on")
        }
    }

    // Методы CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Peripheral did modify services: \(invalidatedServices)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateName name: String?) {
        print("Peripheral did update name: \(name ?? "Unknown")")
    }
}
