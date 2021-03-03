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

import Foundation
import AVKit

class MergeExport: ObservableObject {

  @Published var exportUrl: URL?
  var previewUrl: URL?
  var videoURLS = [URL]()
  let HDVideoSize = CGSize(width: 1920.0, height: 1080.0)

  var uniqueUrl: URL {
    var directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .long
    let date = dateFormatter.string(from: Date())
    directory.appendPathComponent("merge-\(date).mov")
    return directory
  }

  func previewMerge() -> AVPlayerItem {
    let videoAssets = videoURLS.map {
      AVAsset(url: $0)
    }
    let composition = AVMutableComposition()
    if let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)),
       let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {

      var startTime = CMTime.zero
      for asset in videoAssets {
        do {
          try videoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: asset.tracks(withMediaType: .video)[0], at: startTime)
          try audioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: asset.tracks(withMediaType: .audio)[0], at: startTime)
        } catch {
          print("Error creating track")
        }
        startTime = CMTimeAdd(startTime, asset.duration)
      }
    }
    return AVPlayerItem(asset: composition)
  }

  func mergeAndExportVideo() {
    try? FileManager.default.removeItem(at: uniqueUrl)

    let videoAssets = videoURLS.map {
      AVAsset(url: $0)
    }
    let composition = AVMutableComposition()
    let mainInstruction = AVMutableVideoCompositionInstruction()
    if let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)),
       let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {

      var startTime = CMTime.zero
      for asset in videoAssets {
        do {
          try videoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: asset.tracks(withMediaType: .video)[0], at: startTime)
          try audioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: asset.tracks(withMediaType: .audio)[0], at: startTime)
        } catch {
          print("Error creating track")
        }
        let instruction = videoCompositionInstructionFor(track: videoTrack, using: asset)
        instruction.setOpacity(1.0, at: startTime)
        if asset != videoAssets.last {
          instruction.setOpacity(0.0, at: CMTimeAdd(startTime, asset.duration))
        }
        mainInstruction.layerInstructions.append(instruction)
        startTime = CMTimeAdd(startTime, asset.duration)
      }
      let totalDuration = startTime
      mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: totalDuration)
      let videoComposition = AVMutableVideoComposition()
      videoComposition.instructions = [mainInstruction]
      videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
      videoComposition.renderSize = HDVideoSize
      videoComposition.renderScale = 1.0

      guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
      exporter.outputURL = uniqueUrl
      exporter.outputFileType = .mov
      exporter.shouldOptimizeForNetworkUse = true
      exporter.videoComposition = videoComposition

      exporter.exportAsynchronously {
        DispatchQueue.main.async { [weak self] in
          if let exportUrl = exporter.outputURL {
            self?.exportUrl = exportUrl
          }
        }
      }
    }
  }

  func videoCompositionInstructionFor(track: AVCompositionTrack, using asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
    let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    let assetTrack = asset.tracks(withMediaType: .video)[0]
    let transform = assetTrack.preferredTransform
    let assetInfo = orientationFrom(transform: transform)
    var scaleToFitRatio = HDVideoSize.width / assetTrack.naturalSize.width
    if assetInfo.isPortrait {
      scaleToFitRatio = HDVideoSize.height / assetTrack.naturalSize.width
      let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
      let concat = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(CGAffineTransform(translationX: (assetTrack.naturalSize.width * scaleToFitRatio) * 0.60, y: 0))
      instruction.setTransform(concat, at: CMTime.zero)
    } else {
      let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
      let concat = assetTrack.preferredTransform.concatenating(scaleFactor)
      instruction.setTransform(concat, at: CMTime.zero)
    }
    return instruction
  }

  func orientationFrom(transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
    var assetOrientation = UIImage.Orientation.up
    var isPortrait = false
    if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
      isPortrait = true
      assetOrientation = .right
    } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
      isPortrait = true
      assetOrientation = .left
    } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
      assetOrientation = .up
    } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
      assetOrientation = .down
    }
    return (assetOrientation, isPortrait)
  }

}
