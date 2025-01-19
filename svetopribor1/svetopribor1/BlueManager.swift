import CoreBluetooth
import UIKit
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
    var crc32Mac = ""

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

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        NotificationCenter.default.post(name: NSNotification.Name("didDisconnectPeripheral"), object: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.discoverCharacteristics(nil, for: peripheral.services!.first!)
        batteryPeripheral = peripheral
       
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(String(describing: error))")
            return
        }
        selectedDev = peripheral
        for characteristic in service.characteristics! {
            print("Discovered characteristic: \(characteristic.uuid)")
            let targetUUID = CBUUID(string: "D7D4DDBC-0B92-42DB-B412-4BC28DE70FA7")
            if characteristic.properties.contains(.notify) {
                if characteristic.uuid == targetUUID {
                    print("Discovered target characteristic: \(characteristic.uuid)")
                    readChar = characteristic
                    peripheral.readValue(for: characteristic)
                }else{
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }

            if characteristic.properties.contains(.write) {
                writeChar = characteristic
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
        if peripheral != selectedDev{
            return
        }
        if let error = error { print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        let targetUUID = CBUUID(string: "D7D4DDBC-0B92-42DB-B412-4BC28DE70FA7")
       
            if characteristic.uuid == targetUUID {
               
                
                return
            }
        print(UIDevice.current.identifierForVendor!, "fffggg")
        let crc = calculateMACCRC32(macAddress: convertUUIDTo12Format(UIDevice.current.identifierForVendor!))
        // Read characteristics before sending the string
        if let readChar = readChar {
            readCharacteristic(peripheral: peripheral, characteristic: readChar) { value in
                if let readValue = value {
                    let data = readValue
                        if let string = String(data: data, encoding: .utf8) {
                            print("Converted string: \(string)", crc)
                            if string  == crc + "\0" || string == "0\0"{
                                if let value = characteristic.value {
                                   
                                    if let responseString = String(data: value, encoding: .utf8) { print("Received response: \(responseString)")
                                        if responseString == "\0"{
                                            self.sendString(toPeripheral: peripheral, message: "a")
                                            return
                                        }
                                        if responseString == "200\0" || responseString == "412\0"{
                                            
                                            print("гандон сюда")
//                                            self.sendString(toPeripheral: peripheral, message: "w")
                                        }
                                        DispatchQueue.main.async {
                                        self.showAlert(response: responseString)
                                    }
                                        
                                    }
                                } else { print("No value received or unable to decode data")
                                        }
                                print("dcjfnverjnk gfen ge vte vnkgrv kngr")
                            }
                        } else {
                            print("Failed to convert Data to String")
                        }
                    
                }
               
            }
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
        if selectedDev?.state != .connected{
           centralManager.connect(peripheral)
        }
        
        print(UIDevice.current.identifierForVendor!, "fffggg")
        let crc = calculateMACCRC32(macAddress: convertUUIDTo12Format(UIDevice.current.identifierForVendor!))
        // Read characteristics before sending the string
        if let readChar = readChar {
            readCharacteristic(peripheral: peripheral, characteristic: readChar) { value in
                if let readValue = value {
                    let data = readValue
                        if let string = String(data: data, encoding: .utf8) {
                            print("Converted string: \(string)", crc)
                            if string  == crc + "\0" || string == "0\0"{
                                self.performSendString(message: message)
                                print("dcjfnverjnk gfen ge vte vnkgrv kngr")
                            }
                        } else {
                            print("Failed to convert Data to String")
                        }
                    
                }
               
            }
        } else {
//            performSendString(message: message)
        }
    }


    private func readCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic, completion: @escaping (Data?) -> Void) {
        peripheral.readValue(for: characteristic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(characteristic.value)
        }
    }

    private func performSendString(message: String) {
        let fullMessage = message + convertUUIDTo12Format(UIDevice.current.identifierForVendor!)
        if let data = fullMessage.data(using: .utf8) {
            selectedDev?.writeValue(data, for: writeChar!, type: .withResponse)
        }
    }

     func convertUUIDTo12Format(_ uuid: UUID) -> String {
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        var result = ""
        for (index, char) in uuidString.enumerated() {
            result.append(char)
            if index % 2 == 1 && index < 11 {
                result.append(":")
            }
        }
        let mac = result
        let crc32 = calculateMACCRC32(macAddress: mac)
        print("CRC32: \(crc32)")
        crc32Mac = crc32
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

    func calculateMACCRC32(macAddress: String) -> String {
        let cleanMacAddress = macAddress.replacingOccurrences(of: ":", with: "")

        let polynomial: UInt32 = 0xEDB88320
        var crc: UInt32 = 0xFFFFFFFF

        let hexBytes = stride(from: 0, to: cleanMacAddress.count, by: 2).compactMap { index -> UInt8? in
            let start = cleanMacAddress.index(cleanMacAddress.startIndex, offsetBy: index)
            let end = cleanMacAddress.index(start, offsetBy: 2)
            let byteString = String(cleanMacAddress[start..<end])
            return UInt8(byteString, radix: 16)
        }

        for byte in hexBytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
        }

        crc ^= 0xFFFFFFFF
        return String(format: "%08X", crc)
    }


    func handleResponse(response: String) -> String {
        switch response {
        case "0\0":
            print("BLE_CON")
            return "BLE_CON"
        case "200\0":
            print("CONNECT_OK")
            return "CONNECT_OK"
        case "400\0":
            print("DEVICE_BUSY_ERR")
            return "DEVICE_BUSY_ERR"
        case "401\0":
            print("INVALID_MAC_ERR")
            return "INVALID_MAC_ERR"
        case "402\0":
            print("CONNECT_ERR")
            return "CONNECT_ERR"
        case "403\0":
            print("DISCONNECT_ERR")
            return "DISCONNECT_ERR"
        case "201\0":
            print("DISCONNECT_OK")
            return "DISCONNECT_OK"
        case "404\0":
            print("AUDIO_ALREADY_START")
            return "AUDIO_ALREADY_START"
        case "202\0":
            print("AUDIO_START_OK")
            return "AUDIO_START_OK"
        case "405\0":
            print("AUDIO_START_ERR")
            return "AUDIO_START_ERR"
        case "406\0":
            print("AUDIO_ALREADY_STOP")
            return "AUDIO_ALREADY_STOP"
        case "203\0":
            print("AUDIO_STOP_OK")
            return "AUDIO_STOP_OK"
        case "407\0":
            print("AUDIO_STOP_ERR")
            return "AUDIO_STOP_ERR"
        case "408\0":
            print("AUDIO_ALREADY_PAUSE")
            return "AUDIO_ALREADY_PAUSE"
        case "204\0":
            print("AUDIO_PAUSE_OK")
            return "AUDIO_PAUSE_OK"
        case "409\0":
            print("AUDIO_PAUSE_ERR")
            return "AUDIO_PAUSE_ERR"
        case "205\0":
            print("AUDIO_LOUDER_OK")
            return "AUDIO_LOUDER_OK"
        case "206\0":
            print("AUDIO_QUIET_OK")
            return "AUDIO_QUIET_OK"
        case "100\0":
            print("DEFAULT")
            return "DEFAULT"
        case "410\0":
            print("WRONG_MESSAGE")
            return "WRONG_MESSAGE"
        case "411\0":
            print("DEVICE_ISNT_CONNECTED")
            return "DEVICE_ISNT_CONNECTED"
        case "412\0":
            print("DEVICE_ALREADY_CONNECTED")
            return "DEVICE_ALREADY_CONNECTED"
        case "500\0":
            print("DISCONNECT_REQ")
            return "DISCONNECT_REQ"
        case "501\0":
            print("CONTINUE_SESSION_SUC")
            return "CONTINUE_SESSION_SUC"
        case "502\0":
            print("SESSION_TIMEOUT_DISK")
            return "SESSION_TIMEOUT_DISK"
        default:
            print("Unknown response: \(response)")
            return "Unknown response: \(response)"
        }
    }

}
extension Data {
    func hexEncodedString() -> String {
       

        return map { String(format: "%02X", $0) }.joined()
    }
}
