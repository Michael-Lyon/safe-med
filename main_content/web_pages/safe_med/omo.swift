import UIKit
import RoomPlan


class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
   
   @IBOutlet var exportButton: UIButton?
   @IBOutlet var doneButton: UIBarButtonItem?
   @IBOutlet var cancelButton: UIBarButtonItem?
   @IBOutlet var activityIndicator: UIActivityIndicatorView?
   
   // Add a closure to handle completion for Room Result
   var onCompletion: ((_ roomResult: RoomResult?) -> Void)?

   private var isScanning: Bool = false
   private var roomCaptureView: RoomCaptureView!
   private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
   private var finalResults: CapturedRoom?

   override func viewDidLoad() {
       super.viewDidLoad()
       setupRoomCaptureView()
       activityIndicator?.stopAnimating()

       // Setup navigation bar buttons
       self.navigationItem.leftBarButtonItem = cancelButton
       self.navigationItem.rightBarButtonItem = doneButton
   }

   private func setupRoomCaptureView() {
       roomCaptureView = RoomCaptureView(frame: view.bounds)
       roomCaptureView.captureSession.delegate = self
       roomCaptureView.delegate = self
       view.insertSubview(roomCaptureView, at: 0)
   }

   override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
       startSession()
       
   }

   override func viewWillDisappear(_ flag: Bool) {
       super.viewWillDisappear(flag)
       stopSession()
   }

   private func startSession() {
       isScanning = true
       roomCaptureView?.captureSession.run(configuration: roomCaptureSessionConfig)
       setActiveNavBar()
   }

   private func stopSession() {
       isScanning = false
       roomCaptureView?.captureSession.stop()
       setCompleteNavBar()
   }

   // Capture View Delegate - Decide to post-process and show the final results.
   func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
       return true
   }

   // Capture View Delegate - Access the final post-processed results.
   func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
       finalResults = processedResult
       self.exportButton?.isEnabled = true
       self.activityIndicator?.stopAnimating()
   }

   @IBAction func doneScanning(_ sender: UIBarButtonItem) {
       if isScanning {
           stopSession()
       } else {
           cancelScanning(sender)
       }
       self.exportButton?.isEnabled = false
       self.activityIndicator?.startAnimating()
   }

   @IBAction func cancelScanning(_ sender: UIBarButtonItem) {
       // Return to Flutter when cancel button is clicked
       navigationController?.dismiss(animated: true) {
           self.onCompletion?(nil)
       }
   }

   // Export the USDZ output as well as the JSON and generate a thumbnail
   @IBAction func exportResults(_ sender: UIButton) {
       let destinationFolderURL = FileManager.default.temporaryDirectory.appendingPathComponent("Export")
       let destinationURL = destinationFolderURL.appendingPathComponent("Room.usdz")
       let capturedRoomURL = destinationFolderURL.appendingPathComponent("Room.json")
       let thumbnailURL = destinationFolderURL.appendingPathComponent("RoomThumbnail.png")

       do {
           try FileManager.default.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)

           // Encode and save the JSON data
           let jsonEncoder = JSONEncoder()
           let jsonData = try jsonEncoder.encode(finalResults)
           try jsonData.write(to: capturedRoomURL)

           // Export Room as USDZ file
           try finalResults?.export(to: destinationURL, exportOptions: .parametric)

           // Generate and save the thumbnail using QuickLookThumbnailing
           generateThumbnail(for: destinationURL, thumbnailURL: thumbnailURL)

           // Prepare the room result with paths
           let roomResult = RoomResult(usdzPath: destinationURL.path, jsonPath: capturedRoomURL.path, thumbnailPath: thumbnailURL.path)

           // Dismiss the view controller and call the completion handler
           navigationController?.dismiss(animated: true) {
               self.onCompletion?(roomResult)
           }

       } catch {
           print("Error exporting Room = \(error)")
           // Call completion handler with nil to indicate error
           onCompletion?(nil)
       }
   }

   private func setActiveNavBar() {
       UIView.animate(withDuration: 1.0, animations: {
           self.cancelButton?.tintColor = .white
           self.doneButton?.tintColor = .white
           self.exportButton?.alpha = 0.0
       }, completion: { complete in
           self.exportButton?.isHidden = true
       })
   }

   private func setCompleteNavBar() {
       self.exportButton?.isHidden = false
       UIView.animate(withDuration: 1.0) {
           self.cancelButton?.tintColor = .systemBlue
           self.doneButton?.tintColor = .systemBlue
           self.exportButton?.alpha = 1.0
       }
   }
   
   // Generate a thumbnail for the USDZ file using QuickLookThumbnailing
   private func generateThumbnail(for fileURL: URL, thumbnailURL: URL) {
       let size: CGSize = CGSize(width: 180, height: 180) // Customize the size
       let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: size, scale: UIScreen.main.scale, representationTypes: .all)

       let generator = QLThumbnailGenerator.shared
       generator.generateBestRepresentation(for: request) { (thumbnail, error) in
           DispatchQueue.main.async {
               guard let thumbnail = thumbnail, error == nil else {
                   print("Thumbnail generation error: \(String(describing: error))")
                   return
               }

               // Save the thumbnail to disk
               let cgImage = thumbnail.cgImage // No need for optional unwrapping
               let uiImage = UIImage(cgImage: cgImage)
               if let data = uiImage.pngData() {
                   do {
                       try data.write(to: thumbnailURL)
                       print("Thumbnail saved to: \(thumbnailURL)")
                   } catch {
                       print("Error saving thumbnail: \(error)")
                   }
               }
           }
       }
   }
}

// Model to hold the room capture result
struct RoomResult {
   let usdzPath: String
   let jsonPath: String
   let thumbnailPath: String
}
