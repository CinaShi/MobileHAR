# MobileHAR

A Human Activity Recognition Toolkit for iOS platform

## What is it?

This toolkit is aiming to help developers do HAR job easily with a pre-trained state-of-art Conv-LSTM model and several other helpful features implemented. A developer can use it directly in their applications for HAR of 6 basic motions (Walking, Walking_upstairs, Walking_downstairs, Standing, Sitting, Laying) with default setting, or use only the model with their own filters / improvement methods. The Demo app is a great place to start to see how it works. 

## How to use

To install it, simply copy & paste the files in ```HARToolkit``` folder into your own Xcode project. Note that several frameworks/libraries including ```CoreMotion``` and ```GLKit``` might need to be manually linked to your project if they are not already linked.

To use the database feature of the toolkit, you will need to [install Firebase to your project (Cocoapods recommended)](https://cocoapods.org/pods/Firebase). Also, in ```AppDelegate.swift```, following code should be added:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    FirebaseApp.configure()
    return true
}
```

## Key features

### Initialization

You can initialize the toolkit in two ways:
```swift
let toolkit1 = HARToolkit()
let toolkit2 = HARToolkit(turnOnDataPreprocessing: false)
```
Initializing the toolkit with no parameter is defaulting to use data proprocessing implemented in this toolkit (a median filter & a low-pass filter). 

Initializing with parameter is turning data preprocessing off. In this case, the model will process raw sensor data to do the prediction. Developers can use their own data preprocessing methods with this option.

### HAR motion prediction

To do a prediction, you will need to provide a sample with 128 frames (the model is trained against a dataset with 50Hz frame rate and 2.56 sec for one sample, which makes it 128 frames per sample) and 6 features (tri-axial gyroscope data and tri-axial total acceleration data, total acceleration = body acceleration + gravity). All these data could be easily retrieved using Apple's CoreMotion Framework. 
```swift
let resultLabel = toolkit1.predict(gyroXInput: gyroXData, gyroYInput: gyroYData, gyroZInput: gyroZData, accXInput: accXData, accYInput: accYData, accZInput: accZData)
```
The toolkit will check the input size of each features to see if it is 128. If not, an error will be thrown.
If this method is called when Data Preprocessing is turned on, default values of median filter and low-pass filter will be applied.

Also, prediction could also be called alternatively with median filter and low-pass filter parameters included, only if Data Preprocessing is turned on:
```swift
let resultLabel = toolkit1.predict(gyroXInput: gyroXData, gyroYInput: gyroYData, gyroZInput: gyroZData, accXInput: accXData, accYInput: accYData, accZInput: accZData, median_window_size: 3, low_pass_cutoff: 20, low_pass_fs: 50)
```
In this way, you can change the window size of the median filter and cutoff frequency of the low-pass filter when preprocessing the sensor data.

### Coordinate Transformation

Coordinate transformation helps the toolkit to be effective even when the device is carried in orientations / positions different from the one that the model was trained with. Currently, the coordination transformation implemented in this toolkit can only be used consecutively in each frame since its calculation involves user's position and orientation in every frame. Thus, the coordinate transformation function needs to be called in every frame when obtaining sensor data.
```swift
let resultTuple = toolkit1.coordinateTransformation(deviceMotionData: trueData) // motionData can be obtained from CoreMotion
print(resultTuple.0) // Gyroscope X value for current frame
```
The result is a tuple of the transformed 6 features.

### Data upload and data clear

The toolkit will store the sensor data with a global time tag starting from 0 whenever an input comes in. The data can be uploaded to a Firebase database using method in the toolkit. Be cautious that once a model is intialized, it will constantly store data. There is a method that manually clears the stored data. Also, whenever an upload is done, the stored data will be automatically cleared.
```swift
toolkit1.uploadData(uploadActivity: "WALKING")
toolkit1.clearStoredData()
```
The uploaded data will be used to re-train the model periodically or when certain amount of data are collected. Updated model trained with uploaded data will be included in next update of this toolkit.

## Future features

### Local storage and transfer of the data

### Online update of the model
