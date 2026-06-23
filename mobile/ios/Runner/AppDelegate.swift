import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioRecorder: AVAudioRecorder?
  private var recordingURL: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.opcom.opcom_mobile/recorder",
      binaryMessenger: engineBridge.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "start":  self?.startRecording(result: result)
      case "stop":   self?.stopRecording(result: result)
      case "cancel": self?.cancelRecording(result: result)
      default:       result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startRecording(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.record, mode: .default)
      try session.setActive(true)
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("vn_\(Int(Date().timeIntervalSince1970)).m4a")
      recordingURL = url
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
      ]
      audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      audioRecorder?.record()
      result(nil)
    } catch {
      result(FlutterError(code: "REC_ERR", message: error.localizedDescription, details: nil))
    }
  }

  private func stopRecording(result: @escaping FlutterResult) {
    guard let recorder = audioRecorder, let url = recordingURL else {
      result(FlutterError(code: "NO_RECORDER", message: "No active recording", details: nil))
      return
    }
    recorder.stop()
    audioRecorder = nil
    recordingURL = nil
    do {
      let data = try Data(contentsOf: url)
      try? FileManager.default.removeItem(at: url)
      result(FlutterStandardTypedData(bytes: data))
    } catch {
      result(FlutterError(code: "READ_ERR", message: error.localizedDescription, details: nil))
    }
  }

  private func cancelRecording(result: @escaping FlutterResult) {
    audioRecorder?.stop()
    if let url = recordingURL {
      try? FileManager.default.removeItem(at: url)
    }
    audioRecorder = nil
    recordingURL = nil
    result(nil)
  }
}
