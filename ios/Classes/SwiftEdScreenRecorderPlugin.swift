import Flutter
import UIKit
import ReplayKit
import Photos


  struct JsonObj : Codable {
    var file: String
    var isProgress: Bool!
    var eventname: String!
    var message: String?
    var videohash: String!
    var startdate: Int?
    var enddate: Int?
  }

public class SwiftEdScreenRecorderPlugin: NSObject, FlutterPlugin {

  let recorder = RPScreenRecorder.shared()

  var videoOutputURL : URL?
  var videoWriter : AVAssetWriter?

  var audioInput:AVAssetWriterInput!
  var videoWriterInput : AVAssetWriterInput?

  var fileName: String = ""
  var dirPathToSave:NSString = ""
  var isAudioEnabled: Bool! = false;
  var addTimeCode: Bool! = false;
  var filePath: NSString = "";
  var videoFrame: Int?;
  var videoBitrate: Int?;
  var fileOutputFormat: String? = "";
  var fileExtension: String? = "";
  var videoHash: String! = "";
  var startDate: Int?;
  var endDate: Int?;
  var isProgress: Bool! = false;
  var eventName: String! = "";
  var message: String? = "";
    var scale: Double = 1.0;


  var myResult: FlutterResult?
    var startRecordingResult: FlutterResult?
    var stopRecordingResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ed_screen_recorder", binaryMessenger: registrar.messenger())
    let instance = SwiftEdScreenRecorderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      myResult = result
    if(call.method == "startRecordScreen"){
        startRecordingResult = result
        let args = call.arguments as? Dictionary<String, Any>
        self.isAudioEnabled=((args?["audioenable"] as? Bool?)! ?? false)!
        self.fileName=(args?["filename"] as? String)!+".mp4"
        self.dirPathToSave = ((args?["dirpathtosave"] as? NSString) ?? "")
        self.addTimeCode=((args?["addtimecoe"] as? Bool?)! ?? false)!
        self.videoFrame=(args?["videoframe"] as? Int)!
        self.videoBitrate=(args?["videobitrate"] as? Int)!
        self.fileOutputFormat=(args?["fileoutputformat"] as? String)!
        self.fileExtension=(args?["fileextension"] as? String)!
        self.videoHash=(args?["videohash"] as? String)!
        self.scale = (args?["scale"] as? Double ?? 1.0)
        self.isProgress=Bool(true)
        self.eventName=String("startRecordScreen")
        var width: Int32; // in pixels
        var height: Int32; // in pixels
        if UIDevice.current.orientation.isLandscape {
                width = Int32(UIScreen.main.nativeBounds.height); // pixels
           
                height = Int32(UIScreen.main.nativeBounds.width); // pixels
           
        }else{
                width = Int32(UIScreen.main.nativeBounds.width); // pixels
           
                height = Int32(UIScreen.main.nativeBounds.height); // pixels
           
        }
        startRecording(width: Int32(Double(width) * scale) ,height: Int32(Double(height) * scale) );
        self.startDate=Int(NSDate().timeIntervalSince1970 * 1_000)
        let jsonObject: JsonObj = JsonObj(
          file: String("\(self.filePath)/\(self.fileName)"),
          isProgress: Bool(self.isProgress),
          eventname: String(self.eventName ?? "eventName"),
          message: String(self.message!),
          videohash: String(self.videoHash),
          startdate: Int(self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000)),
          enddate: Int(self.endDate ?? 0)
        )
        let encoder = JSONEncoder()
        let json = try! encoder.encode(jsonObject)
        let jsonStr = String(data:json,encoding: .utf8)
        result(jsonStr)
    }else if(call.method == "stopRecordScreen"){
        stopRecordingResult = result
        
        if(videoWriter != nil){stopRecording()
            self.isProgress=Bool(false)
            self.eventName=String("stopRecordScreen")
            self.endDate=Int(NSDate().timeIntervalSince1970 * 1_000)
        }else{
            stopRecordingResult?(FlutterError(code:
                "There is no Video Writer!", message: nil, details: nil))
            stopRecordingResult = nil
        }
        
        
    } else if (call.method == "pauseRecordingScreen") {
        result(true)
    }
      else if (call.method == "resumeRecordingScreen") {
        result(true)
      }
  }

  func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map{ _ in letters.randomElement()! })
  }

    @objc func startRecording(width: Int32, height: Int32) -> Void {
    if(recorder.isAvailable){
        NSLog("startRecording: w x h = \(width) x \(height) pixels");
        if self.dirPathToSave != "" {
            self.filePath = dirPathToSave as NSString
            self.videoOutputURL = URL(fileURLWithPath: String(self.filePath.appendingPathComponent(fileName)))
        } else {
            self.filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
            self.videoOutputURL = URL(fileURLWithPath: String(self.filePath.appendingPathComponent(fileName)))
        }
        do {
            let fileManager = FileManager.default
            if (fileManager.fileExists(atPath: videoOutputURL!.path)){
            try FileManager.default.removeItem(at: videoOutputURL!)}
        } catch let error as NSError{
            print("Error", error);
            startRecordingResult?(FlutterError(code: String(error.code), message: error.localizedDescription, details: error.description))
            startRecordingResult = nil
        }

        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL!, fileType: AVFileType.mp4)
            self.message=String("Started Video")
        } catch let writerError as NSError {
            print("Error opening video file", writerError);
            self.message=String(writerError as! Substring) as String
            videoWriter = nil;
            startRecordingResult?(FlutterError(code: String(writerError.code), message: writerError.localizedDescription, details:writerError.description))
            startRecordingResult = nil
        }
        if #available(iOS 11.0, *) {
            recorder.isMicrophoneEnabled = isAudioEnabled
            let videoSettings: [String : Any] = [
                AVVideoCodecKey  : AVVideoCodecType.h264,
                AVVideoWidthKey  : NSNumber.init(value: width),
                AVVideoHeightKey : NSNumber.init(value: height),
                AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAverageBitRateKey: self.videoBitrate!
                ] as [String : Any],
            ]
            self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings);
            self.videoWriterInput?.expectsMediaDataInRealTime = true;
            self.videoWriter?.add(videoWriterInput!);
            if(isAudioEnabled){
                let audioOutputSettings: [String : Any] = [
                    AVNumberOfChannelsKey : 2,
                    AVFormatIDKey : kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
                self.audioInput?.expectsMediaDataInRealTime = true;
                self.videoWriter?.add(audioInput!);
            }
        }
            if #available(iOS 11.0, *) {
                recorder.startCapture(handler: { 
                    (cmSampleBuffer, rpSampleType, error) in guard error == nil else {
                            return;
                    }
                    switch rpSampleType {
                        case RPSampleBufferType.video:
                            if self.videoWriter?.status == AVAssetWriter.Status.unknown {
                                self.videoWriter?.startWriting()
                                self.videoWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer));
                            }else if self.videoWriter?.status == AVAssetWriter.Status.writing {
                                if (self.videoWriterInput?.isReadyForMoreMediaData == true) {
                                    if  self.videoWriterInput?.append(cmSampleBuffer) == false {
                                        print("Problems writing video")
                                        self.startRecordingResult?(FlutterError(code:"Problems writing video",message: "Problems writing video",details:"Problems writing video" ))
                                        self.startRecordingResult=nil
                                        
                                    }
                                }
                            }
                            case RPSampleBufferType.audioMic:
                                if(self.isAudioEnabled){
                                    if self.audioInput?.isReadyForMoreMediaData == true {
                                        if self.audioInput?.append(cmSampleBuffer) == false {
                                            print("Problems writing audio")
                                            self.startRecordingResult?(FlutterError(code:"Problems writing audio",message: "Problems writing audio",details:"Problems writing audio" ))
                                            self.startRecordingResult=nil
                                        }
                                    }
                                }
                            default:
                            break;
                    }
                }){(error) in if error == nil {
                    let jsonObject: JsonObj = JsonObj(
                      file: String("\(self.filePath)/\(self.fileName)"),
                      isProgress: Bool(self.isProgress),
                      eventname: String(self.eventName ?? "eventName"),
                      message: String(self.message!),
                      videohash: String(self.videoHash),
                      startdate: Int(self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000)),
                      enddate: Int(self.endDate ?? 0)
                    )
                    let encoder = JSONEncoder()
                    let json = try! encoder.encode(jsonObject)
                    let jsonStr = String(data:json,encoding: .utf8)
                    self.startRecordingResult?(jsonStr)
                    self.startRecordingResult = nil
                    return
                } else {
                    self.startRecordingResult?(FlutterError(code: String(error!.localizedDescription), message: error!.localizedDescription, details: error!.localizedDescription))
                    self.startRecordingResult = nil
                    }
                }
            }
        }
    }

    @objc func stopRecording() -> Void {
        if(recorder.isRecording){
            if #available(iOS 11.0, *) {
                recorder.stopCapture( handler: { (error) in
                    print("Stopping recording...");
                    if(error != nil){
                        self.message = "Has Got Error in stop record"
                        self.stopRecordingResult?(FlutterError(code: error!.localizedDescription, message: error!.localizedDescription, details: error!.localizedDescription))
                        self.stopRecordingResult=nil
                    }
                })
            } else {
                self.message="You dont Support this plugin"
                stopRecordingResult?(FlutterError(code:"You dont Support this plugin", message:"You dont Support this plugin", details:"You dont Support this plugin"))
            stopRecordingResult = nil
            }

            self.videoWriterInput?.markAsFinished();
            if(self.isAudioEnabled) {
                self.audioInput?.markAsFinished();
            }

            self.videoWriter?.finishWriting {
                print("Finished writing video");
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoOutputURL!)
                })
                self.message="stopRecordScreenFromApp"
                let jsonObject: JsonObj = JsonObj(
                  file: String("\(self.filePath)/\(self.fileName)"),
                  isProgress: Bool(self.isProgress),
                  eventname: String(self.eventName ?? "eventName"),
                  message: String(self.message!),
                  videohash: String(self.videoHash),
                  startdate: Int(self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000)),
                  enddate: Int(self.endDate ?? 0)
                )
                let encoder = JSONEncoder()
                let json = try! encoder.encode(jsonObject)
                let jsonStr = String(data:json,encoding: .utf8)
                self.stopRecordingResult?(jsonStr)
                self.stopRecordingResult=nil
            }
        }else{
            self.message="You haven't start the recording unit now!"
            stopRecordingResult?(FlutterError(code:"You haven't start the recording unit now!", message:"You haven't start the recording unit now!", details:"You haven't start the recording unit now!"))
            stopRecordingResult = nil
        }

}
}
