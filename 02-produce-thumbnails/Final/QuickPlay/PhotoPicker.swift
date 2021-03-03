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
import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {

  typealias UIViewControllerType = PHPickerViewController

  @Binding var isPresented: Bool
  @Binding var videos: [URL]

  func makeUIViewController(context: Context) -> PHPickerViewController {
    var configuration = PHPickerConfiguration()
    configuration.selectionLimit = 0
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {

  }

  func makeCoordinator() -> PickerCoordinator {
    PickerCoordinator(photoPicker: self)
  }

  class PickerCoordinator: PHPickerViewControllerDelegate {

    let photoPicker: PhotoPicker
    let urls = [URL]()

    init(photoPicker: PhotoPicker) {
      self.photoPicker = photoPicker
      photoPicker.videos.removeAll()
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      for result in results {
        let itemProvider = result.itemProvider
        guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first,
              let uType = UTType(typeIdentifier) else {
          return
        }
        if uType.conforms(to: .movie) {
          itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            if let error = error {
              print(error.localizedDescription)
            } else {
              guard let videoURL = url else { return }
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
              guard let targetURL = documentsDirectory?.appendingPathComponent(videoURL.lastPathComponent) else {
                return
              }
              do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                  try FileManager.default.removeItem(at: targetURL)
                }
                try FileManager.default.copyItem(at: videoURL, to: targetURL)
                DispatchQueue.main.async {
                  self.photoPicker.videos.append(targetURL)
                }
              } catch {
                // handle error
              }
            }
          }
        }
      }
      photoPicker.isPresented = false
    }
  }
}
