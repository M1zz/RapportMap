//
//  ImagePicker.swift
//  RapportMap
//
//  Created by hyunho lee on 11/10/25.
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss
    var onImageSelected: (() -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 업데이트 필요 없음
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ 이미지 로드 실패: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let uiImage = image as? UIImage else { return }
                    
                    // 이미지 압축 및 리사이징
                    let resizedImage = self.resizeImage(uiImage, targetSize: CGSize(width: 400, height: 400))
                    
                    // JPEG로 압축 (0.8 품질)
                    if let jpegData = resizedImage.jpegData(compressionQuality: 0.8) {
                        DispatchQueue.main.async {
                            self.parent.imageData = jpegData
                            self.parent.onImageSelected?()
                            print("✅ 프로필 사진 업데이트 완료 (크기: \(jpegData.count / 1024)KB)")
                        }
                    }
                }
            }
        }
        
        /// 이미지를 지정된 크기로 리사이징
        private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
            let size = image.size
            
            let widthRatio  = targetSize.width  / size.width
            let heightRatio = targetSize.height / size.height
            
            // 비율을 유지하면서 리사이징
            var newSize: CGSize
            if widthRatio > heightRatio {
                newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
            } else {
                newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
            }
            
            let rect = CGRect(origin: .zero, size: newSize)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return newImage ?? image
        }
    }
}
