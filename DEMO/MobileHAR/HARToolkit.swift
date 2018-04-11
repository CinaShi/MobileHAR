//
//  HARToolkit.swift
//  MobileHAR
//
//  Created by Mengyang Shi on 4/11/18.
//  Copyright © 2018 Ubicomp. All rights reserved.
//

import CoreML
import CoreMotion
import Accelerate
import Foundation
import GLKit
import Firebase

// Contains all errors that might be thrown by HARModel
public enum HARToolkitError: Error {
    case InvalidInputsError(String)
    case InvalidOutputError(String)
}

// A Conv-LSTM deep learning model for Human Activity Recognition
public final class HARToolkit {
    
    // HAR Model
    fileprivate let model: ConvLSTM
    // Whether to turn on default data preprocessing layers for input data
    fileprivate var dataPreprocessingOn: Bool
    // Gyroscope X axis input for one sample (128 frames)
    fileprivate var gyroXInput = [Double]()
    // Gyroscope Y axis input for one sample (128 frames)
    fileprivate var gyroYInput = [Double]()
    // Gyroscope Z axis input for one sample (128 frames)
    fileprivate var gyroZInput = [Double]()
    // Accelerometer X axis input for one sample (128 frames)
    fileprivate var accXInput = [Double]()
    // Accelerometer Y axis input for one sample (128 frames)
    fileprivate var accYInput = [Double]()
    // Accelerometer Z axis input for one sample (128 frames)
    fileprivate var accZInput = [Double]()
    // Aggregated Input Array for HAR Model input
    fileprivate var inputArray = MultiArray<Double>(shape: [1,128,6])
    // Last Velocity saved for Coordinate Transformation
    fileprivate var lastVelocity = [Double]()
    // Last Acceleration saved for Coordinate Transformation
    fileprivate var lastAcc = [Double]()
    // store all data that have been processed by this model
    var allDataArray = [(Int, Double, Double, Double, Double, Double, Double)]()
    // counter that increase whenver a frame has been processed
    var globalCounter = 0
    
    // initialize the HAR Model with different settings
    public init(turnOnDataPreprocessing: Bool = true) {
        self.model = ConvLSTM()
        self.dataPreprocessingOn = turnOnDataPreprocessing
    }
    
    public func predict(gyroXInput: [Double], gyroYInput: [Double], gyroZInput: [Double], accXInput: [Double], accYInput: [Double], accZInput: [Double], median_window_size: Int = 3,  low_pass_cutoff: Double = 20, low_pass_fs: Double = 50) throws -> String {
        
        if gyroXInput.count != 128 || gyroYInput.count != 128 || gyroZInput.count != 128 || accXInput.count != 128 || accYInput.count != 128 || accZInput.count != 128 {
            throw HARToolkitError.InvalidInputsError("Your input sample for each feature should all have 128 frames.")
        }
        
        self.gyroXInput = gyroXInput
        self.gyroYInput = gyroYInput
        self.gyroZInput = gyroZInput
        self.accXInput = accXInput
        self.accYInput = accYInput
        self.accZInput = accZInput
        
        if self.dataPreprocessingOn {
            self.gyroXInput = self.lowPass(data: self.gyroXInput, cutoff: low_pass_cutoff, fs: low_pass_fs)
            self.gyroYInput = self.lowPass(data: self.gyroYInput, cutoff: low_pass_cutoff, fs: low_pass_fs)
            self.gyroZInput = self.lowPass(data: self.gyroZInput, cutoff: low_pass_cutoff, fs: low_pass_fs)
            self.accXInput = self.lowPass(data: self.accXInput, cutoff: low_pass_cutoff, fs: low_pass_fs)
            self.accYInput = self.lowPass(data: self.accYInput, cutoff: low_pass_cutoff, fs: low_pass_fs)
            self.accZInput = self.lowPass(data: self.accZInput, cutoff: low_pass_cutoff, fs: low_pass_fs)
            
            //use only median filter
            self.gyroXInput = self.median_filter(data: self.gyroXInput, window_size: median_window_size)
            self.gyroYInput = self.median_filter(data: self.gyroYInput, window_size: median_window_size)
            self.gyroZInput = self.median_filter(data: self.gyroZInput, window_size: median_window_size)
            self.accXInput = self.median_filter(data: self.accXInput, window_size: median_window_size)
            self.accYInput = self.median_filter(data: self.accYInput, window_size: median_window_size)
            self.accZInput = self.median_filter(data: self.accZInput, window_size: median_window_size)
        }
        
        for i in 0...127 {
            self.inputArray[0,i,0] = self.gyroXInput[i]
            self.inputArray[0,i,1] = self.gyroYInput[i]
            self.inputArray[0,i,2] = self.gyroZInput[i]
            self.inputArray[0,i,3] = self.accXInput[i]
            self.inputArray[0,i,4] = self.accYInput[i]
            self.inputArray[0,i,5] = self.accZInput[i]
            
            self.allDataArray.append((globalCounter, self.gyroXInput[i], self.gyroYInput[i], self.gyroZInput[i], self.accXInput[i], self.accYInput[i], self.accZInput[i]))
            globalCounter += 1
        }
        
        let inputs = ConvLSTMInput(input: self.inputArray.array)
        let output = try? self.model.prediction(input: inputs)
        
        if output == nil {
            throw HARToolkitError.InvalidOutputError("Model is unable to process an appropriate output. Probably caused by abnormal input values (e.g. values too large to be normal sensor value).")
        }
        
        return output!.classLabel
    }
    
    public func turnOnDataPreprocessing() {
        self.dataPreprocessingOn = true
    }
    
    public func turnOffDataPreprocessing() {
        self.dataPreprocessingOn = false
    }
    
    public func coordinateTransformation(deviceMotionData: CMDeviceMotion) -> (Double, Double, Double, Double, Double, Double) {
        let rotationVector = deviceMotionData.attitude.quaternion
        
        var accData = [Double]()
        var gyroData = [Double]()
        accData.append(deviceMotionData.userAcceleration.x+deviceMotionData.gravity.x)
        accData.append(deviceMotionData.userAcceleration.y+deviceMotionData.gravity.y)
        accData.append(deviceMotionData.userAcceleration.z+deviceMotionData.gravity.z)
        gyroData.append(deviceMotionData.rotationRate.x)
        gyroData.append(deviceMotionData.rotationRate.y)
        gyroData.append(deviceMotionData.rotationRate.z)
        
        (accData, gyroData) = self.coordinate_transform_world(rotationVector: rotationVector, accData: accData, gyroData: gyroData)
        
//        if isFirstSample {
//            self.lastVelocity = [0, 0, 0]
//            self.lastAcc = [0, 0, 0]
//        }
//
//        let currentVelocity = self.calculateVelocity(lastVelocity: self.lastVelocity, currentAcc: accData, lastAcc: self.lastAcc, deltaT: deltaT)
//
//        self.lastVelocity = currentVelocity
//        self.lastAcc = accData
        
        return (-gyroData[2], -gyroData[1], -gyroData[0], -accData[2], -accData[1], -accData[0])
    }
    
    public func clearStoredData() {
        self.allDataArray.removeAll()
        self.globalCounter = 0
    }
    
    public func uploadData(uploadActivity: String) {
        let storageRef = Storage.storage().reference()
        let fileRef = storageRef.child("data/\(NSUUID().uuidString)-\(uploadActivity).csv")
        
        let uploadString = createUploadString()
        let uploadFilePath = NSTemporaryDirectory() + "\(uploadActivity).csv"
        let uploadFileURL = NSURL(fileURLWithPath: uploadFilePath)
        FileManager.default.createFile(atPath: uploadFilePath, contents: NSData() as Data, attributes: nil)
        
        var fileHandle: FileHandle? = nil
        do {
            fileHandle = try FileHandle(forWritingTo: uploadFileURL as URL)
        } catch {
            print("Error with fileHandle")
        }
        
        if fileHandle != nil {
            fileHandle!.seekToEndOfFile()
            let csvData = uploadString.data(using: String.Encoding.utf8, allowLossyConversion: false)
            fileHandle!.write(csvData!)
            
            fileHandle!.closeFile()
        }
        
        let uploadTask = fileRef.putFile(from: uploadFileURL as URL, metadata: nil) { metadata, error in
            if let error = error {
                print("error occurs, \n\(error)")
            } else {
                let downLoadURL = metadata!.downloadURL()
                print("download URL: \(String(describing: downLoadURL))")
            }
        }
        
        uploadTask.observe(.success) { snapchat in
            print("\(snapchat.status)")
        }
    }
    
    private func createUploadString() -> String {
        
        var export: String = NSLocalizedString("timestamp, gyroX, gyroY, gyroZ, tAccX, tAccY, tAccZ \n", comment: "")
        for (index, sensorData) in self.allDataArray.enumerated() {
            if index <= allDataArray.count - 1 {
                export += "\(sensorData.0),\(sensorData.1),\(sensorData.2),\(sensorData.3),\(sensorData.4),\(sensorData.5),\(sensorData.6) \n"
            }
        }
        print("This is what the app will export: \(export)")
        return export
    }
    
    // coordinate transformation implementation
    private func coordinate_transform_world(rotationVector: CMQuaternion, accData: [Double], gyroData: [Double]) -> ([Double], [Double]) {
        let quaternion = GLKQuaternionMake(Float(rotationVector.x), Float(rotationVector.y), Float(rotationVector.z), Float(rotationVector.w))
        let conjQuaternion = GLKQuaternionConjugate(quaternion)
        
        let accVector = GLKQuaternionMake(Float(accData[0]), Float(accData[1]), Float(accData[2]), 0)
        let gyroVector = GLKQuaternionMake(Float(gyroData[0]), Float(gyroData[1]), Float(gyroData[2]), 0)
        
        let accMulti1 = GLKQuaternionMultiply(quaternion, accVector)
        let accMulti2 = GLKQuaternionMultiply(accMulti1, conjQuaternion)
        
        let gyroMulti1 = GLKQuaternionMultiply(quaternion, gyroVector)
        let gyroMulti2 = GLKQuaternionMultiply(gyroMulti1, conjQuaternion)
        
        var accData = [Double]()
        var gyroData = [Double]()
        accData.append(Double(accMulti2.x))
        accData.append(Double(accMulti2.y))
        accData.append(Double(accMulti2.z))
        gyroData.append(Double(gyroMulti2.x))
        gyroData.append(Double(gyroMulti2.y))
        gyroData.append(Double(gyroMulti2.z))
        
        return (accData, gyroData)
    }
    
//    public func calculateVelocity(lastVelocity: [Double], currentAcc: [Double], lastAcc: [Double], deltaT: Double) -> [Double] {
//        let velX = lastVelocity[0] + deltaT / 2 * (currentAcc[0] - lastAcc[0]) + deltaT * lastAcc[0]
//        let velY = lastVelocity[1] + deltaT / 2 * (currentAcc[1] - lastAcc[1]) + deltaT * lastAcc[1]
//        let velZ = lastVelocity[2] + deltaT / 2 * (currentAcc[2] - lastAcc[2]) + deltaT * lastAcc[2]
//
//        var newVelocity = [Double]()
//        newVelocity.append(velX)
//        newVelocity.append(velY)
//        newVelocity.append(velZ)
//
//        return newVelocity
//    }
    
    // Below are implementation of median filter
    private func median_filter(data: [Double], window_size: Int = 3) -> [Double] {
        let begin = data[0]
        let end = data[data.count - 1]
        
        var output = [Double]()
        
        for i in 0...data.count-1 {
            var medianArray = [Double]()
            if i < window_size {
                for _ in 1...window_size - i {
                    medianArray.append(begin)
                }
                for k in 0...i + window_size - 1 {
                    medianArray.append(data[k])
                }
            } else if i > data.count - 1 - window_size {
                for k in i - window_size...data.count - 1 {
                    medianArray.append(data[k])
                }
                for _ in 1...i - data.count + 1 + window_size {
                    medianArray.append(end)
                }
            } else {
                for k in i - window_size...i + window_size - 1 {
                    medianArray.append(data[k])
                }
            }
            output.append(medianArray.median())
        }
        
        return output
    }
    
    // Below are implementation of simple low pass filter
    private func lowPass(data: [Double], cutoff: Double = 20, fs: Double = 50) -> [Double] {
        let dt:Double = 1.0 / fs
        let RC:Double = 1.0 / cutoff
        let alpha = dt / (dt + RC)
        
        var result = [Double]()
        
        result.append(data[0])
        for k in 1...data.count-1 {
            result.append(data[k] * alpha + data[k-1] * (1-alpha))
        }
        return result
    }
}

extension Array where Element == Double {
    func median() -> Double {
        let sortedArray = sorted()
        if count % 2 != 0 {
            return sortedArray[count / 2]
        } else {
            return (sortedArray[count / 2] + sortedArray[count / 2 - 1]) / 2.0
        }
    }
}
