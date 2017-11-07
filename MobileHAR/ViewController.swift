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

class ViewController: UIViewController {

    @IBOutlet weak var recogLabel: UILabel!
    @IBOutlet weak var filteredRecogLabel: UILabel!
    
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    
    let model = ConvLSTM()
    var rawSensorDataArray = MultiArray<Double>(shape: [1,128,6])
    var filteredSensorDataArray = MultiArray<Double>(shape: [1,128,6])
    
    
    var gyroXData = [Double]()
    var gyroYData = [Double]()
    var gyroZData = [Double]()
    var accXData = [Double]()
    var accYData = [Double]()
    var accZData = [Double]()
    
    var motion = CMMotionManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        startBtn.isEnabled = true
        stopBtn.isEnabled = false
    }

    
    @IBAction func startRecording(_ sender: Any) {
        startBtn.isEnabled = false
        stopBtn.isEnabled = true
        
        print("motion recording started")
        motion.deviceMotionUpdateInterval = 0.02
        var counter = 0
        motion.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {(data,error) in
            if let trueData = data {
                if counter == 128 {
                    let input = ConvLSTMInput(input: self.rawSensorDataArray.array)
                    let output = try? self.model.prediction(input: input)
                    self.recogLabel.text =  "You are \(output?.classLabel ?? "doing nothing"). "
                    
                    //filter data
                    
                    self.gyroXData = self.butter_lowpass_filter(data: self.median_filter(data: self.gyroXData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    self.gyroYData = self.butter_lowpass_filter(data: self.median_filter(data: self.gyroYData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    self.gyroZData = self.butter_lowpass_filter(data: self.median_filter(data: self.gyroZData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    self.accXData = self.butter_lowpass_filter(data: self.median_filter(data: self.accXData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    self.accYData = self.butter_lowpass_filter(data: self.median_filter(data: self.accYData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    self.accZData = self.butter_lowpass_filter(data: self.median_filter(data: self.accZData, window_size: 3), cutoff: 20, fs: 50, order: 3)
                    
                    for i in 0...127 {
                        self.filteredSensorDataArray[0,i,0] = self.gyroXData[i]
                        self.filteredSensorDataArray[0,i,1] = self.gyroYData[i]
                        self.filteredSensorDataArray[0,i,2] = self.gyroZData[i]
                        self.filteredSensorDataArray[0,i,3] = self.gyroXData[i]
                        self.filteredSensorDataArray[0,i,4] = self.accYData[i]
                        self.filteredSensorDataArray[0,i,5] = self.accZData[i]
                    }
                    
                    let filteredInput = ConvLSTMInput(input: self.filteredSensorDataArray.array)
                    let filteredOutput = try? self.model.prediction(input: filteredInput)
                    self.filteredRecogLabel.text =  "You are \(filteredOutput?.classLabel ?? "doing nothing"). "
                    
                    self.gyroXData.removeAll()
                    self.gyroYData.removeAll()
                    self.gyroZData.removeAll()
                    self.accXData.removeAll()
                    self.accYData.removeAll()
                    self.accZData.removeAll()
                    
                    counter = 0
                }
                self.rawSensorDataArray[0,counter,0] = trueData.rotationRate.x
                self.rawSensorDataArray[0,counter,1] = trueData.rotationRate.y
                self.rawSensorDataArray[0,counter,2] = trueData.rotationRate.z
                self.rawSensorDataArray[0,counter,3] = trueData.userAcceleration.x+trueData.gravity.x
                self.rawSensorDataArray[0,counter,4] = trueData.userAcceleration.y+trueData.gravity.y
                self.rawSensorDataArray[0,counter,5] = trueData.userAcceleration.z+trueData.gravity.z
                
                // filter ones here
                self.gyroXData.append(trueData.rotationRate.x)
                self.gyroYData.append(trueData.rotationRate.y)
                self.gyroZData.append(trueData.rotationRate.z)
                self.accXData.append(trueData.userAcceleration.x+trueData.gravity.x)
                self.accYData.append(trueData.userAcceleration.y+trueData.gravity.y)
                self.accZData.append(trueData.userAcceleration.z+trueData.gravity.z)
                
                counter = counter + 1
            }
            
        })
    }
    
    
    @IBAction func stopRecording(_ sender: Any) {
        startBtn.isEnabled = true
        stopBtn.isEnabled = false
        
        motion.stopDeviceMotionUpdates()
        print("motion recording stopped")
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

