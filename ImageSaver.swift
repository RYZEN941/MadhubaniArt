import UIKit

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        // This is the core function that talks to your iPad's Photos app
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Save error: \(error.localizedDescription)")
        } else {
            print("Save finished successfully!")
        }
    }
}
