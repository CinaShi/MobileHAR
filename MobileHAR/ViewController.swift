//
//  ViewController.swift
//  MobileHAR
//
//  Created by Mengyang Shi on 11/5/17.
//  Copyright © 2017 Ubicomp. All rights reserved.
//

import UIKit
import CoreML
import CoreMotion
import Darwin
import Accelerate
import GLKit
import Firebase

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var recogLabel: UILabel!
    @IBOutlet weak var filteredRecogLabel: UILabel!
    
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    
    @IBOutlet weak var inHandSwitch: UISwitch!
    //UI for testing data
    
    @IBOutlet weak var rawAccuracy: UILabel!
    @IBOutlet var rawMeans: [UILabel]!
    
    @IBOutlet weak var filteredAccuracy: UILabel!
    @IBOutlet var filteredMeans: [UILabel]!

    @IBOutlet weak var sampleSize: UILabel!
    
    @IBOutlet var uploadDataButton: UIButton!
    
    let model = ConvLSTM()
    var rawSensorDataArray = MultiArray<Double>(shape: [1,128,6])
    var filteredSensorDataArray = MultiArray<Double>(shape: [1,128,6])
    
    var existedArray = [String]()
    var lastMeans = [Double]()
    var positionChangeCount = 0
    
    var gyroXData = [Double]()
    var gyroYData = [Double]()
    var gyroZData = [Double]()
    var accXData = [Double]()
    var accYData = [Double]()
    var accZData = [Double]()
    
    var motion = CMMotionManager()
    
    var lastVelocity = [Double]()
    var lastAcc = [Double]()
    
    var sensorDataArray = [(Int, Double, Double, Double, Double, Double, Double)]()
    
    @IBOutlet var activityPickerView: UIPickerView!
    
    let activityPickerViewData = ["WALKING", "WALKING_UPSTAIRS", "WALKING_DOWNSTAIRS", "SITTING", "STANDING", "LAYING"]
    
    var uploadActivity: String = ""
    
    //Vars for testing
    let destinatedLabel = "STANDING"
    
    var sampleCount = 0
    
    var allRawGyroXData = [Double]()
    var allRawGyroYData = [Double]()
    var allRawGyroZData = [Double]()
    var allRawAccXData = [Double]()
    var allRawAccYData = [Double]()
    var allRawAccZData = [Double]()
    
    var rawCorrectPredCount = 0.0
    var rawAllPredCount = 0.0
    
    var allFilteredGyroXData = [Double]()
    var allFilteredGyroYData = [Double]()
    var allFilteredGyroZData = [Double]()
    var allFilteredAccXData = [Double]()
    var allFilteredAccYData = [Double]()
    var allFilteredAccZData = [Double]()
    
    var filteredCorrectPredCount = 0.0
    var filteredAllPredCount = 0.0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        startBtn.isEnabled = true
        stopBtn.isEnabled = false
        uploadDataButton.isEnabled = false
        
        uploadActivity = activityPickerViewData[0]
        activityPickerView.delegate = self
        activityPickerView.dataSource = self
    }
    
    @IBAction func startRecording(_ sender: Any) {
        startBtn.isEnabled = false
        stopBtn.isEnabled = true
        uploadDataButton.isEnabled = false
        print("motion recording started")
        motion.deviceMotionUpdateInterval = 0.02
        var counter = 0
        var globalCounter = 0
        motion.startDeviceMotionUpdates(using:.xMagneticNorthZVertical, to: OperationQueue.current!, withHandler: {(data,error) in
            if let trueData = data {
                if counter == 128 {
                    //raw data output
                    let input = ConvLSTMInput(input: self.rawSensorDataArray.array)

                    let output = try? self.model.prediction(input: input)

//                    print(input.input.shape)

//                    if output == nil {
//                        fatalError("unexpected runtime error")
//                    }
                    
                    //do position change detection first
                    
//                    if self.lastMeans.count == 0 {
//                        self.lastMeans.append((self.allRawAccXData.reduce(0, +)/Double(self.allRawAccXData.count)))
//                        self.lastMeans.append((self.allRawAccYData.reduce(0, +)/Double(self.allRawAccYData.count)))
//                        self.lastMeans.append((self.allRawAccZData.reduce(0, +)/Double(self.allRawAccZData.count)))
//                        self.lastMeans.append((self.allRawGyroXData.reduce(0, +)/Double(self.allRawGyroXData.count)))
//                        self.lastMeans.append((self.allRawGyroYData.reduce(0, +)/Double(self.allRawGyroYData.count)))
//                        self.lastMeans.append((self.allRawGyroZData.reduce(0, +)/Double(self.allRawGyroZData.count)))
//                    } else {
//                        var currentMeans = [Double]()
//                        currentMeans.append((self.allRawAccXData.reduce(0, +)/Double(self.allRawAccXData.count)))
//                        currentMeans.append((self.allRawAccYData.reduce(0, +)/Double(self.allRawAccYData.count)))
//                        currentMeans.append((self.allRawAccZData.reduce(0, +)/Double(self.allRawAccZData.count)))
//                        currentMeans.append((self.allRawGyroXData.reduce(0, +)/Double(self.allRawGyroXData.count)))
//                        currentMeans.append((self.allRawGyroYData.reduce(0, +)/Double(self.allRawGyroYData.count)))
//                        currentMeans.append((self.allRawGyroZData.reduce(0, +)/Double(self.allRawGyroZData.count)))
//
//                        var positionChanged = false
//                        let changeFactor = 25.0
//
//                        for i in 0...5 {
//                            let meanDiff = abs(self.lastMeans[i] - currentMeans[i])
//                            if meanDiff > abs(self.lastMeans[i]) * changeFactor || meanDiff > abs(currentMeans[i]) * changeFactor {
//                                positionChanged = true
//                            }
//                        }
//
//                        if positionChanged {
//                            self.existedArray.removeAll()
//                            self.positionChangeCount += 1
//                        }
//
//                        self.lastMeans = currentMeans
//                    }
                    
                    
                    // use new algo to improve prediction
                    self.existedArray.append((output?.classLabel)!)
                    let outputLabel = output?.classLabel
                    
//                    let unique = Array(Set(self.existedArray))
//                    for label in unique {
//                        if Double(self.existedArray.filter{$0 == label}.count) / Double(self.existedArray.count) > 0.5 {
//                            outputLabel = label
//                            break
//                        }
//                    }

                    self.recogLabel.text =  "You are \(outputLabel ?? "doing nothing"). "
                    
                    //testing
                    
                    if outputLabel == self.destinatedLabel {
                        self.rawCorrectPredCount += 1
                    }
                    self.rawAllPredCount += 1
                    self.rawAccuracy.text = "\(self.rawCorrectPredCount/self.rawAllPredCount)"

                    self.rawMeans[0].text = "\(self.allRawAccXData.reduce(0, +)/Double(self.allRawAccXData.count))"
                    self.rawMeans[1].text = "\(self.allRawAccYData.reduce(0, +)/Double(self.allRawAccYData.count))"
                    self.rawMeans[2].text = "\(self.allRawAccZData.reduce(0, +)/Double(self.allRawAccZData.count))"
                    self.rawMeans[3].text = "\(self.allRawGyroXData.reduce(0, +)/Double(self.allRawGyroXData.count))"
                    self.rawMeans[4].text = "\(self.allRawGyroYData.reduce(0, +)/Double(self.allRawGyroYData.count))"
                    self.rawMeans[5].text = "\(self.allRawGyroZData.reduce(0, +)/Double(self.allRawGyroZData.count))"
                    
                    //filter data output
                    
//                    self.gyroXData = self.butter_lowpass_filter(data: self.median_filter(data: self.gyroXData, window_size: 3), cutoff: 20, fs: 50, order: 3)
//                    self.gyroYData = self.butter_lowpass_filter(data: self.median_filter(data: self.gyroYData, window_size: 3), cutoff: 20, fs: 50, order: 3)
//                    self.gyroZData = self.butter_lowpass_filter(data: self.median_filter(data: self.gyroZData, window_size: 3), cutoff: 20, fs: 50, order: 3)
//                    self.accXData = self.butter_lowpass_filter(data: self.median_filter(data: self.accXData, window_size: 3), cutoff: 20, fs: 50, order: 3)
//                    self.accYData = self.butter_lowpass_filter(data: self.median_filter(data: self.accYData, window_size: 3), cutoff: 20, fs: 50, order: 3)
//                    self.accZData = self.butter_lowpass_filter(data: self.median_filter(data: self.accZData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    self.gyroXData = self.lowPass(data: self.gyroXData, cutoff: 20, fs: 50)
                    self.gyroYData = self.lowPass(data: self.gyroYData, cutoff: 20, fs: 50)
                    self.gyroZData = self.lowPass(data: self.gyroZData, cutoff: 20, fs: 50)
                    self.accXData = self.lowPass(data: self.accXData, cutoff: 20, fs: 50)
                    self.accYData = self.lowPass(data: self.accYData, cutoff: 20, fs: 50)
                    self.accZData = self.lowPass(data: self.accZData, cutoff: 20, fs: 50)
                    
                    //use only median filter
                    self.gyroXData = self.median_filter(data: self.gyroXData, window_size: 3)
                    self.gyroYData = self.median_filter(data: self.gyroYData, window_size: 3)
                    self.gyroZData = self.median_filter(data: self.gyroZData, window_size: 3)
                    self.accXData = self.median_filter(data: self.accXData, window_size: 3)
                    self.accYData = self.median_filter(data: self.accYData, window_size: 3)
                    self.accZData = self.median_filter(data: self.accZData, window_size: 3)
                    
                    for i in 0...127 {
                        self.filteredSensorDataArray[0,i,0] = self.gyroXData[i]
                        self.filteredSensorDataArray[0,i,1] = self.gyroYData[i]
                        self.filteredSensorDataArray[0,i,2] = self.gyroZData[i]
                        self.filteredSensorDataArray[0,i,3] = self.accXData[i]
                        self.filteredSensorDataArray[0,i,4] = self.accYData[i]
                        self.filteredSensorDataArray[0,i,5] = self.accZData[i]
                        
                        self.sensorDataArray.append((globalCounter, self.gyroXData[i], self.gyroYData[i], self.gyroZData[i], self.accXData[i], self.accYData[i], self.accZData[i]))
                        globalCounter += 1
                        
                        //testing
                        self.allFilteredGyroXData.append(self.gyroXData[i])
                        self.allFilteredGyroYData.append(self.gyroYData[i])
                        self.allFilteredGyroZData.append(self.gyroZData[i])
                        self.allFilteredAccXData.append(self.accXData[i])
                        self.allFilteredAccYData.append(self.accYData[i])
                        self.allFilteredAccZData.append(self.accZData[i])
                    }
                    
                    let filteredInput = ConvLSTMInput(input: self.filteredSensorDataArray.array)
                    
                    let filteredOutput = try? self.model.prediction(input: filteredInput)
                    
                    self.existedArray.append((filteredOutput?.classLabel)!)
                    
//                    print(filteredInput.input.shape)
//
//                    if filteredOutput == nil {
//                        fatalError("unexpected runtime error")
//                    }
                    
                    self.filteredRecogLabel.text =  "You are \(filteredOutput?.classLabel ?? "doing nothing"). "
                    
                    self.gyroXData.removeAll()
                    self.gyroYData.removeAll()
                    self.gyroZData.removeAll()
                    self.accXData.removeAll()
                    self.accYData.removeAll()
                    self.accZData.removeAll()
                    
                    counter = 0
                    
                    //testing
                    
                    if filteredOutput?.classLabel == self.destinatedLabel {
                        self.filteredCorrectPredCount += 1
                    }
                    self.filteredAllPredCount += 1
                    self.filteredAccuracy.text = "\(self.filteredCorrectPredCount/self.filteredAllPredCount)"
                    
                    self.filteredMeans[0].text = "\(self.allFilteredAccXData.reduce(0, +)/Double(self.allFilteredAccXData.count))"
                    self.filteredMeans[1].text = "\(self.allFilteredAccYData.reduce(0, +)/Double(self.allFilteredAccYData.count))"
                    self.filteredMeans[2].text = "\(self.allFilteredAccZData.reduce(0, +)/Double(self.allFilteredAccZData.count))"
                    self.filteredMeans[3].text = "\(self.allFilteredGyroXData.reduce(0, +)/Double(self.allFilteredGyroXData.count))"
                    self.filteredMeans[4].text = "\(self.allFilteredGyroYData.reduce(0, +)/Double(self.allFilteredGyroYData.count))"
                    self.filteredMeans[5].text = "\(self.allFilteredGyroZData.reduce(0, +)/Double(self.allFilteredGyroZData.count))"
                    
                    
                    self.sampleCount += 1
                    self.sampleSize.text = "size: \(self.sampleCount), position changed: \(self.positionChangeCount)"
                    
                }
                
                if self.inHandSwitch.isOn {
                    // test coordinate transformation here
                    
                    let rotationVector = trueData.attitude.quaternion
                    
                    print(rotationVector)
                    
                    var accData = [Double]()
                    var gyroData = [Double]()
                    accData.append(trueData.userAcceleration.x+trueData.gravity.x)
                    accData.append(trueData.userAcceleration.y+trueData.gravity.y)
                    accData.append(trueData.userAcceleration.z+trueData.gravity.z)
                    gyroData.append(trueData.rotationRate.x)
                    gyroData.append(trueData.rotationRate.y)
                    gyroData.append(trueData.rotationRate.z)
                    
                    // test tranformation to world coordinate
                    (accData, gyroData) = self.coordinate_transform_world(rotationVector: rotationVector, accData: accData, gyroData: gyroData)
                    
                    
                    
                    // test transformation to user-centric coordinate
                    if counter == 0 {
                        self.lastVelocity = [0, 0, 0]
                        self.lastAcc = [0, 0, 0]
                    }
                    let currentVelocity = self.calculateVelocity(lastVelocity: self.lastVelocity, currentAcc: accData, lastAcc: self.lastAcc, deltaT: self.motion.deviceMotionUpdateInterval.magnitude)
                    
                    self.lastVelocity = currentVelocity
                    self.lastAcc = accData
                    
//                    (accData, gyroData) = self.coordinate_transform_user(currentVel: currentVelocity, accData: accData, gyroData: gyroData)
                    //after world - acc
                    // x = -z
                    // y = -y
                    // z = -x
                    
                    //after world - gyro
                    // x = -z
                    // y = -y
                    // z = -x
                    
                    //after u-c
                    // x = -z
                    // y = -y
                    // z = x
                    
                    //raw data here
                    self.rawSensorDataArray[0,counter,0] = -gyroData[2]
                    self.rawSensorDataArray[0,counter,1] = -gyroData[1]
                    self.rawSensorDataArray[0,counter,2] = -gyroData[0]
                    self.rawSensorDataArray[0,counter,3] = -accData[2]
                    self.rawSensorDataArray[0,counter,4] = -accData[1]
                    self.rawSensorDataArray[0,counter,5] = -accData[0]
                    
                    // filter data here
                    self.gyroXData.append(-gyroData[2])
                    self.gyroYData.append(-gyroData[1])
                    self.gyroZData.append(-gyroData[0])
                    self.accXData.append(-accData[2])
                    self.accYData.append(-accData[1])
                    self.accZData.append(-accData[0])
                    
                    // testing
                    self.allRawGyroXData.append(-gyroData[2])
                    self.allRawGyroYData.append(-gyroData[1])
                    self.allRawGyroZData.append(-gyroData[0])
                    self.allRawAccXData.append(-accData[2])
                    self.allRawAccYData.append(-accData[1])
                    self.allRawAccZData.append(-accData[0])
                    
//                    //raw data here
//                    self.rawSensorDataArray[0,counter,0] = -trueData.rotationRate.y
//                    self.rawSensorDataArray[0,counter,1] = trueData.rotationRate.x
//                    self.rawSensorDataArray[0,counter,2] = trueData.rotationRate.z
//                    self.rawSensorDataArray[0,counter,3] = -trueData.userAcceleration.y-trueData.gravity.y
//                    self.rawSensorDataArray[0,counter,4] = trueData.userAcceleration.x+trueData.gravity.x
//                    self.rawSensorDataArray[0,counter,5] = trueData.userAcceleration.z+trueData.gravity.z
//
//                    // filter data here
//                    self.gyroXData.append(-trueData.rotationRate.y)
//                    self.gyroYData.append(trueData.rotationRate.x)
//                    self.gyroZData.append(trueData.rotationRate.z)
//                    self.accXData.append(-trueData.userAcceleration.y-trueData.gravity.y)
//                    self.accYData.append(trueData.userAcceleration.x+trueData.gravity.x)
//                    self.accZData.append(trueData.userAcceleration.z+trueData.gravity.z)
//
//                    // testing
//                    self.allRawGyroXData.append(-trueData.rotationRate.y)
//                    self.allRawGyroYData.append(trueData.rotationRate.x)
//                    self.allRawGyroZData.append(trueData.rotationRate.z)
//                    self.allRawAccXData.append(-trueData.userAcceleration.y-trueData.gravity.y)
//                    self.allRawAccYData.append(trueData.userAcceleration.x+trueData.gravity.x)
//                    self.allRawAccZData.append(trueData.userAcceleration.z+trueData.gravity.z)
                    
                } else {
                    
                    //raw data here
                    self.rawSensorDataArray[0,counter,0] = trueData.rotationRate.x
                    self.rawSensorDataArray[0,counter,1] = trueData.rotationRate.y
                    self.rawSensorDataArray[0,counter,2] = trueData.rotationRate.z
                    self.rawSensorDataArray[0,counter,3] = trueData.userAcceleration.x+trueData.gravity.x
                    self.rawSensorDataArray[0,counter,4] = trueData.userAcceleration.y+trueData.gravity.y
                    self.rawSensorDataArray[0,counter,5] = trueData.userAcceleration.z+trueData.gravity.z

                    // filter data here
                    self.gyroXData.append(trueData.rotationRate.x)
                    self.gyroYData.append(trueData.rotationRate.y)
                    self.gyroZData.append(trueData.rotationRate.z)
                    self.accXData.append(trueData.userAcceleration.x+trueData.gravity.x)
                    self.accYData.append(trueData.userAcceleration.y+trueData.gravity.y)
                    self.accZData.append(trueData.userAcceleration.z+trueData.gravity.z)

                    // testing
                    self.allRawGyroXData.append(trueData.rotationRate.x)
                    self.allRawGyroYData.append(trueData.rotationRate.y)
                    self.allRawGyroZData.append(trueData.rotationRate.z)
                    self.allRawAccXData.append(trueData.userAcceleration.x+trueData.gravity.x)
                    self.allRawAccYData.append(trueData.userAcceleration.y+trueData.gravity.y)
                    self.allRawAccZData.append(trueData.userAcceleration.z+trueData.gravity.z)
                    
                }
                
                counter = counter + 1
            }
            
        })
    }
    
    
    @IBAction func stopRecording(_ sender: Any) {
        startBtn.isEnabled = true
        stopBtn.isEnabled = false
        uploadDataButton.isEnabled = true
        motion.stopDeviceMotionUpdates()
        print("motion recording stopped")
    }
    
    @IBAction func uploadData(_ sender: Any) {
//        let countedSet = NSCountedSet(array: existedArray)
//        let mostFrequent = countedSet.max { countedSet.count(for: $0) < countedSet.count(for: $1) } as! String
//        uploadActivity = mostFrequent
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
    
    func createUploadString() -> String {
        
        var export: String = NSLocalizedString("timestamp, gyroX, gyroY, gyroZ, tAccX, tAccY, tAccZ \n", comment: "")
        for (index, sensorData) in sensorDataArray.enumerated() {
            if index <= sensorDataArray.count - 1 {
                export += "\(sensorData.0),\(sensorData.1),\(sensorData.2),\(sensorData.3),\(sensorData.4),\(sensorData.5),\(sensorData.6) \n"
            }
        }
        print("This is what the app will export: \(export)")
        return export
    }
    
    @IBAction func downloadModel(_ sender: Any) {
        
    }
    
    //pickerview delegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int{
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        return activityPickerViewData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return activityPickerViewData[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int){
        uploadActivity = activityPickerViewData[row]
    }
    
    // coordinate transformation
    
    func coordinate_transform_world(rotationVector: CMQuaternion, accData: [Double], gyroData: [Double]) -> ([Double], [Double]) {
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
    
    func calculateVelocity(lastVelocity: [Double], currentAcc: [Double], lastAcc: [Double], deltaT: Double) -> [Double] {
        let velX = lastVelocity[0] + deltaT / 2 * (currentAcc[0] - lastAcc[0]) + deltaT * lastAcc[0]
        let velY = lastVelocity[1] + deltaT / 2 * (currentAcc[1] - lastAcc[1]) + deltaT * lastAcc[1]
        let velZ = lastVelocity[2] + deltaT / 2 * (currentAcc[2] - lastAcc[2]) + deltaT * lastAcc[2]
        
        var newVelocity = [Double]()
        newVelocity.append(velX)
        newVelocity.append(velY)
        newVelocity.append(velZ)
        
        return newVelocity
    }
    
    func coordinate_transform_user(currentVel: [Double], accData: [Double], gyroData: [Double]) -> ([Double], [Double]) {
        //calculate eX, eY and eZ to get tranformation matrix
        let eX = normalize_vector(vector: currentVel)
        
        //cross product: (0, 0, 1) x eX
        var eY = [Double]()
        eY.append(-eX[1])
        eY.append(eX[0])
        eY.append(0)
        eY = normalize_vector(vector: eY)
        
        //cros product: eX x eY
        var eZ = [Double]()
        eZ.append(eX[1] * eY[2] - eX[2] * eY[1])
        eZ.append(eX[2] * eY[0] - eX[0] * eY[2])
        eZ.append(eX[0] * eY[1] - eX[1] * eY[0])
        
        //now we have transformation matrix R = (eX, eY, eZ)
        var accVector = [Double]()
        var gyroVector = [Double]()
        
        accVector.append(eX[0] * accData[0] + eY[0] * accData[1] + eZ[0] * accData[2])
        accVector.append(eX[1] * accData[0] + eY[1] * accData[1] + eZ[1] * accData[2])
        accVector.append(eX[2] * accData[0] + eY[2] * accData[1] + eZ[2] * accData[2])
        
        gyroVector.append(eX[0] * gyroData[0] + eY[0] * gyroData[1] + eZ[0] * gyroData[2])
        gyroVector.append(eX[1] * gyroData[0] + eY[1] * gyroData[1] + eZ[1] * gyroData[2])
        gyroVector.append(eX[2] * gyroData[0] + eY[2] * gyroData[1] + eZ[2] * gyroData[2])
        
        return (accVector, gyroVector)
    }
    
    func normalize_vector(vector: [Double]) -> [Double] {
        var lengthSumSq: Double = 0
        for unit in vector {
            lengthSumSq += unit * unit
        }
        let vector_length = lengthSumSq.squareRoot()
        var norm_vector = [Double]()
        norm_vector.append((vector[0] / vector_length))
        norm_vector.append((vector[1] / vector_length))
        norm_vector.append((vector[2] / vector_length))
        return norm_vector
    }
    
    // Below are implementation of median filter
    
    func median_filter(data: [Double], window_size: Int = 3) -> [Double] {
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
    
    func lowPass(data: [Double], cutoff: Double, fs: Double) -> [Double] {
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
    
    
    // Below are implementation of low-pass butterworth filter originated from SciPy
    
    func butter_lowpass(cutoff: Double, fs: Double, order: Double = 5.0) -> ([Double], [Double]) {
        let nyq = 0.5 * fs
        let normal_cutoff = cutoff / nyq
        return butter(order: order, cutoff: normal_cutoff)
    }
    
    func butter_lowpass_filter(data: [Double], cutoff: Double, fs: Double, order: Double = 5.0) -> [Double] {
        var b = [Double]()
        var a = [Double]()
        (b, a) = butter_lowpass(cutoff: cutoff, fs: fs, order: order)
        return lfilter(b, a, data)
    }
    
    func lfilter(_ b: [Double], _ a:[Double], _ data:[Double]) -> [Double] {
        let filterSize = b.count > a.count ? b.count : a.count
        var newB = [Double](b)
        var newA = [Double](a)
        
        if b.count < filterSize {
            let diff = filterSize - b.count
            for _ in 1...diff {
                newB.append(0.0)
            }
        }
        
        if a.count < filterSize {
            let diff = filterSize - a.count
            for _ in 1...diff {
                newA.append(0.0)
            }
        }
        
        var z = [Double](repeating: 0.0, count: filterSize-1)
        
        var output = [Double]()
        
        let a0 = newA[0]
        for k in 0...data.count-1 {
            if b.count > 1 {
                output.append(z[0] + newB[0] / a0 * data[k])
                for n in 0...newB.count - 3 {
                    z[n] = z[1] + data[k] * (newB[n+1] / a0) - output[k] * (newA[n+1] / a0)
                }
                z[z.count-1] = data[k] * (newB[newB.count-1] / a0) - output[k] * (newA[newA.count-1] / a0)
            } else {
                output.append(data[k] * (newB[0] / a0))
            }
        }
        
        return output
    }
    
    func butter(order: Double, cutoff: Double) -> ([Double], [Double]) {
        var z = [Complex]()
        var p = [Complex]()
        var k = Double()
        (z, p, k) = buttaq(order)
        
        let fs = 2.0
        let warped = 2 * fs * tan(Double.pi * cutoff / fs)
        
        (z, p, k) = zpklp2lp(z, p, k, warped)
        (z, p, k) = zpkbilinear(z, p, k, fs)
        return zpk2tf(z, p, k)
    }
    
    func buttaq(_ order: Double) -> ([Complex], [Complex], Double) {
        let z = [Complex]()
        var p = [Complex]()
        var count = 1 - order
        while count < order {
            let imaginePart = Complex(0, 1)
            let realPart = Complex(Double.pi * count / (2 * order), 0)
            let combined = imaginePart * realPart
            p.append(-exp(combined))
            count = count + 2.0
        }
        let k = 1.0
        return (z, p, k)
    }
    
    func zpklp2lp(_ z: [Complex], _ p: [Complex], _ k: Double, _ wo: Double) -> ([Complex], [Complex], Double) {
        let degree = p.count - z.count
        
        var z_lp = [Complex]()
        var p_lp = [Complex]()
        
        for elem in z {
            z_lp.append(elem * Complex(k, 0))
        }
        
        for elem in p {
            p_lp.append(elem * Complex(k, 0))
        }
        
        let k_lp = pow(wo, Double(degree)) * k
        
        return (z_lp, p_lp, k_lp)
    }
    
    func zpkbilinear(_ z: [Complex], _ p: [Complex], _ k: Double, _ fs: Double) -> ([Complex], [Complex], Double) {
        let degree = p.count - z.count
        
        let fs2 = fs * 2
        
        var z_z = [Complex]()
        var p_z = [Complex]()
        
        for elem in z {
            z_z.append((elem + Complex(fs2, 0)) / (Complex(fs2, 0) - elem))
        }
        
        for elem in p {
            p_z.append((elem + Complex(fs2, 0)) / (Complex(fs2, 0) - elem))
        }
        
        var counter = degree
        while counter > 0 {
            z_z.append(Complex(-1, 0))
            counter = counter - 1
        }
        
        var zProd = Complex(fs2, 0) - z_z[0]
        for (index, elem) in z.enumerated() {
            if index != 0 {
                zProd = zProd * (Complex(fs2, 0) - elem)
            }
        }
        
        var pProd = Complex(fs2, 0) - p_z[0]
        for (index, elem) in p.enumerated() {
            if index != 0 {
                pProd = pProd * (Complex(fs2, 0) - elem)
            }
        }
        
        let prodDiv = zProd / pProd
        let k_z = k * prodDiv.real
        
        return (z_z, p_z, k_z)
    }
    
    func zpk2tf(_ z: [Complex], _ p: [Complex], _ k: Double) -> ([Double], [Double]) {
        var b = [Double]()
        let polyZ = poly(z)
        
        for elem in polyZ {
            b.append((Complex(k) * elem).real)
        }
        
        var a = [Double]()
        let polyP = poly(p)
        
        for elem in polyP {
            a.append(elem.real)
        }
        
        return (b, a)
    }
    
    func poly(_ roots:[Complex]) -> [Complex] {
        
        var coefficients = [Complex](repeating: Complex(1), count: 1)
        
        for k in 0...roots.count-1 {
            var kComplex = [Complex]()
            kComplex.append(Complex(1))
            kComplex.append(-roots[k])
            coefficients = convolve(coefficients, kComplex)
        }
        
        return coefficients
    }
    
    func convolve(_ x:[Complex], _ y:[Complex]) -> [Complex] {
        
        var longArray:[Complex]
        var shortArray:[Complex]
        
        if x.count < y.count {
            
            longArray = [Complex](y)
            shortArray = [Complex](x)
            
        } else {
            
            longArray = [Complex](x)
            shortArray = [Complex](y)
            
        }
        
        let N = longArray.count
        let M = shortArray.count
        let convN = N+M-1
        var output = [Complex](repeating: Complex(0.0), count: convN)
        
        // padding leading zeros
        longArray = [Complex](repeating: Complex(0.0), count: (convN-N)) + longArray
        
        var complexShortReal = [Double]()
        var complexShortImag = [Double]()
        for elem in shortArray.reversed() {
            complexShortReal.append(elem.real)
            complexShortImag.append(elem.imag)
        }
        var complexShort = DSPDoubleSplitComplex(realp: &complexShortReal, imagp: &complexShortImag)
        
        var complexLongReal = [Double]()
        var complexLongImag = [Double]()
        for elem in longArray {
            complexLongReal.append(elem.real)
            complexLongImag.append(elem.imag)
        }
        var complexLong = DSPDoubleSplitComplex(realp: &complexLongReal, imagp: &complexLongImag)
        
        var complexOutputReal = [Double]()
        var complexOutputImag = [Double]()
        for elem in output {
            complexOutputReal.append(elem.real)
            complexOutputImag.append(elem.imag)
        }
        var complexOutput = DSPDoubleSplitComplex(realp: &complexOutputReal, imagp: &complexOutputImag)
        
//        let ptr_longArrayFirstElement = UnsafePointer<DSPDoubleSplitComplex>(complexLong)
//        let ptr_shortArrayLastElement = UnsafePointer<DSPDoubleSplitComplex>(complexShort).advanced(by:shortArray.count - 1)
//        let ptr_output = UnsafeMutablePointer<DSPDoubleSplitComplex>(mutating: output)
        
        vDSP_zconvD(&complexLong, 1, &complexShort, 1,
                   &complexOutput, 1, vDSP_Length(convN), vDSP_Length(M))
    
        for index in 0...output.count-1 {
            output[index] = Complex(complexOutputReal[index], complexOutputImag[index])
        }
        return output
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

