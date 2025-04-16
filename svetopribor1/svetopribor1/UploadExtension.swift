//
//  UploadExtension.swift
//  svetopribor1
//
//  Created by Maksimilian on 7.04.25.
//

import Foundation
extension BluetoothManager{
    func sendCurrentPacket() {
        guard !shouldStopUpdate else {
            print("Обновление остановлено. Цикл отправки прерван.")
            isUpdating = false
            return
        }
        let index = extractPacketIndex(from: adminReadchar?.value)
        print(index, "ind")
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        // Если пакеты закончились, завершаем обновление.
        guard index - 999 < packets.count else {
            finishUpdate()
            return
        }
        
        let packet = packets[index - 999]
        let crcString = formatCRC32ToMAC(crc32: crc32Mac)
        
        // Формируем префикс: "b" + crcString
        guard let prefixData = ("b" + crcString).data(using: .utf8) else {
            print("Ошибка при преобразовании префикса в данные.")
            return
        }
        
        // Преобразуем currentPacketIndex в 2-байтовое представление (big endian).
        var packetIndex = UInt16(index + 1).bigEndian
        let indexData = Data(bytes: &packetIndex, count: MemoryLayout<UInt16>.size)
        
        // Объединяем данные: префикс, номер пакета и сам пакет.
        var fullPacketData = Data()
        fullPacketData.append(prefixData)
        fullPacketData.append(indexData)
        fullPacketData.append(packet)
        
        // Отправляем данные
        selectedDev?.writeValue(fullPacketData, for: updateCharacteristic, type: .withoutResponse)
        
        // Планируем отправку следующего пакета через 20 мс, только если обновление активно.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
            guard let self = self else { return }
            if self.isUpdating && !self.shouldStopUpdate {
                // Если ещё не достигнут конец, или же повторная попытка не исчерпана:
                if index - 999 < self.packets.count {
                    
                    let progress = Float(index - 999) / Float(packets.count)
                    NotificationCenter.default.post(name: Notification.Name("updateProgress"), object: nil, userInfo: ["progress": progress])
                    NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "осталось пакетов " +  String(self.packets.count - index + 1000)])
                    self.sendCurrentPacket()
                } else {
                    self.finishUpdate()
                }
            } else {
                print("Отправка следующего пакета отменена, так как обновление остановлено.")
            }
        }
    }
    func extractPacketIndex(from data: Data?) -> Int {
        guard let data = data,
              let rawString = String(data: data, encoding: .utf8) else {
            return 999
        }
        // Удаляем пробелы, переводы строк и нулевые символы
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.filter { $0 != "\0" }
        // Если в конце строки есть '/', удаляем его (если это нужно по формату)
        let finalString = cleaned.hasSuffix("/") ? String(cleaned.dropLast()) : cleaned
        if Int(finalString) == 0{
            return 999
        }
        return Int(finalString) ?? 999
    }
    
    // Делегатский метод, который вызывается после завершения записи
   
    
    
    // Обновлённый обработчик ответа.
    // Например, если устройство возвращает число, которое говорит о проблеме — продолжить с этого номера.
    func handlePacketResponse(_ receivedPacketNumber: Int) {
        // Если значение равно тому же, что уже отправлялось,
        // увеличиваем счетчик ошибок; иначе – сбрасываем его.
        if receivedPacketNumber == currentPacketIndex {
            retryCounter += 1
            if retryCounter >= maxRetries {
                shouldStopUpdate = true
                print("Превышено максимальное число повторных ошибок (\(retryCounter)), обновление остановлено.")
                return
            }
        } else {
            retryCounter = 0
            currentPacketIndex = receivedPacketNumber
        }
        
        // Продолжаем, если есть еще пакеты.
        if currentPacketIndex < packets.count {
            sendCurrentPacket()
        } else {
            finishUpdate()
        }
    }
    
    // Пример метод start/update
    func startUpdate(audioNumber: Int) {
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        // Инициализация необходимых переменных для обновления.
        shouldStopUpdate = false
        
        currentPacketIndex = 0
        retryCounter = 0
        
        
        // Отправляем команду старта обновления (например, "a" + crc + audioNumber)
        let startCommand = "a\(formatCRC32ToMAC(crc32: crc32Mac))\(audioNumber)".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
        
        // Возможно, здесь можно запустить отправку первого пакета после подтверждения устройства.
        // Или же вызвать sendCurrentPacket() напрямую, если устройство готово.
    }
    func deleteUpdate(audioNumber: Int) {
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        // Инициализация необходимых переменных для обновления.
        shouldStopUpdate = false
        //        isUpdating = true
        currentPacketIndex = 0
        retryCounter = 0
        
        
        // Отправляем команду старта обновления (например, "a" + crc + audioNumber)
        let startCommand = "x\(formatCRC32ToMAC(crc32: crc32Mac))\(audioNumber)".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
        
        // Возможно, здесь можно запустить отправку первого пакета после подтверждения устройства.
        // Или же вызвать sendCurrentPacket() напрямую, если устройство готово.
    }
    
    
    func removeAll(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "z\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    
    
    func playAudio(){
        
    }
    func reset(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "f\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func fetchAudio(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "w\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func fetchMemory(){
        guard let _ = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        let startCommand = "h\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        selectedDev?.writeValue(startCommand, for: updateCharacteristic!, type: .withResponse)
    }
    func finishUpdate() {
        
        // Отправляем команду завершения (например, "c" + crc)
        guard let updateCharacteristic = updateCharacteristic else {
            print("Характеристика для обновления не найдена.")
            return
        }
        
        let crc32Result = calculateCombinedCRC32ByMerging(for: packets)
        
        var packetIndex = crc32Result.bigEndian
        let indexData = Data(bytes: &packetIndex, count: MemoryLayout<UInt32>.size)
        print("1crc32:", packetIndex)
        NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "через 2 сек"])
        var finishCommand = "c\(formatCRC32ToMAC(crc32: crc32Mac))".data(using: .utf8)!
        finishCommand.append(indexData)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            self.selectedDev?.writeValue(finishCommand, for: updateCharacteristic, type: .withResponse)
            NotificationCenter.default.post(name: NSNotification.Name("didReceiveResponse"), object: nil, userInfo: ["response": "crc " + String(packetIndex)])
        }
        print("Обновление завершено.")
    }
    
    // Остальные методы остаются без изменений...
    
    
    // Остальные методы остаются без изменений...
    
    
}
