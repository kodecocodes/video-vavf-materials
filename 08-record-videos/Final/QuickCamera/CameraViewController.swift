///// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import AVFoundation
import SwiftUI
import PhotosUI

class CameraViewController: UIViewController {

  let captureSession = AVCaptureSession()
  var previewLayer: AVCaptureVideoPreviewLayer!
  var activeInput: AVCaptureDeviceInput!
  let movieOutput = AVCaptureMovieFileOutput()

  var tempURL: URL? {
    let directory = NSTemporaryDirectory() as NSString
    if directory != "" {
      let path = directory.appendingPathComponent("video.mov")
      return URL(fileURLWithPath: path)
    }
    return nil
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    setupSession()
    setupPreview()
    startSession()
  }

  override func viewWillDisappear(_ animated: Bool) {
    stopSession()
  }

  func setupSession() {
    captureSession.beginConfiguration()
    guard let camera = AVCaptureDevice.default(for: .video) else {
      return
    }
    guard let mic = AVCaptureDevice.default(for: .audio) else {
      return
    }
    do {
      let videoInput = try AVCaptureDeviceInput(device: camera)
      let audioInput = try AVCaptureDeviceInput(device: mic)
      for input in [videoInput, audioInput] {
        if captureSession.canAddInput(input) {
          captureSession.addInput(input)
        }
      }
      activeInput = videoInput
    } catch {
      print("Error setting device input: \(error)")
      return
    }
    captureSession.addOutput(movieOutput)
    captureSession.commitConfiguration()
  }

  func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    let devices = discovery.devices.filter {
      $0.position == position
    }
    return devices.first
  }

  public func switchCamera() {
    let position: AVCaptureDevice.Position = (activeInput.device.position == .back) ? .front : .back
    guard let device = camera(for: position) else {
        return
    }
    captureSession.beginConfiguration()
    captureSession.removeInput(activeInput)
    do {
      activeInput = try AVCaptureDeviceInput(device: device)
    } catch {
      print("error: \(error.localizedDescription)")
      return
    }
    captureSession.addInput(activeInput)
    captureSession.commitConfiguration()
  }

  func setupPreview() {
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.frame = view.bounds
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    view.layer.addSublayer(previewLayer)
  }

  func startSession() {
    if !captureSession.isRunning {
      DispatchQueue.global(qos: .default).async { [weak self] in
        self?.captureSession.startRunning()
      }
    }
  }

  func stopSession() {
    if captureSession.isRunning {
      DispatchQueue.global(qos: .default).async() { [weak self] in
        self?.captureSession.stopRunning()
      }
    }
  }

  public func captureMovie() {
    guard let connection = movieOutput.connection(with: .video) else {
      return
    }
    if connection.isVideoStabilizationSupported {
      connection.preferredVideoStabilizationMode = .auto
    }
    let device = activeInput.device
    if device.isSmoothAutoFocusEnabled {
      do {
        try device.lockForConfiguration()
        device.isSmoothAutoFocusEnabled = true
        device.unlockForConfiguration()
      } catch {
        print("error: \(error)")
      }
    }
    guard let outUrl = tempURL else { return }
    movieOutput.startRecording(to: outUrl, recordingDelegate: self)
  }

  public func stopRecording() {
    if movieOutput.isRecording {
      movieOutput.stopRecording()
    }
  }

}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    if let error = error {
      print("error: \(error.localizedDescription)")
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
          PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
          } completionHandler: { (success, error) in

          }
        }
      }
    }
  }
}
