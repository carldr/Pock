//
//  SWifiItem.swift
//  Pock
//
//  Created by Pierluigi Galdi on 23/02/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults
import Carbon

class SLangItem: StatusItem {
    
    
    /// UI
    private let iconView: NSImageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
    
    var tisInputSource: TISInputSource? = nil
    
    init() {}
    
    deinit {
        didUnload()
    }
    
    var enabled: Bool{ return Defaults[.shouldShowWifiItem] }
    
    var title: String  { return "lang" }
    
    var view: NSView { return iconView }
    
    func action() {
        if !isProd { print("[Pock]: Lang Status icon tapped!") }
    }
    
    
    func didLoad() {
        iconView.imageAlignment = NSImageAlignment.alignCenter
        self.reload()
        // register input source listener
        DistributedNotificationCenter.default().addObserver(self,
        selector: #selector(selectedKeyboardInputSourceChanged),
        name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
        object: nil,
        suspensionBehavior: .deliverImmediately)
    }
    
    func didUnload() {
        DistributedNotificationCenter.default().removeObserver(self, name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil)
    }
    
    
    func reload() {
        // check if there is need to change the input source icon
        let tisInputSourceLocal = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if (tisInputSource?.name == tisInputSourceLocal.name) {
            return
        }
        tisInputSource = nil
        tisInputSource = tisInputSourceLocal
        var iconImage: NSImage? = nil
        // try getting high-res icon url
        if let imageURL = tisInputSource!.iconImageURL {
            for url in [imageURL.retinaImageURL, imageURL.tiffImageURL, imageURL] {
                if let image = NSImage(contentsOf: url) {
                    iconImage = image
                    break
                }
            }
        }

        // get the iconRef if no high-res icon url is available
        if iconImage == nil, let iconRef = tisInputSource!.iconRef {
            iconImage = NSImage(iconRef: iconRef)
        }
        
        // resize in order to fit the touchbar without blurriness when too big
        self.iconView.image = iconImage?.resizeWhileMaintainingAspectRatioToSize(size: NSSize(width: 18, height: 18))
        
    }
    
}

extension SLangItem {
    // this may be called twice
    @objc func selectedKeyboardInputSourceChanged() {
        self.reload()
    }
}

//credit: https://github.com/utatti/kawa
private extension URL {
    // try getting retina image from URL
    var retinaImageURL: URL {
        var components = pathComponents
        let filename: String = components.removeLast()
        let ext: String = pathExtension
        let retinaFilename = filename.replacingOccurrences(of: "." + ext, with: "@2x." + ext)
        return NSURL.fileURL(withPathComponents: components + [retinaFilename])!
    }

    // try getting high quality tiff from URL
    var tiffImageURL: URL {
        return deletingPathExtension().appendingPathExtension("tiff")
    }
}

// extension which makes getting properties from TISInputSource easier
extension TISInputSource {
    enum Category {
        static var keyboardInputSource: String {
            return kTISCategoryKeyboardInputSource as String
        }
    }

    private func getProperty(_ key: CFString) -> AnyObject? {
        let cfType = TISGetInputSourceProperty(self, key)
        if (cfType != nil) {
            return Unmanaged<AnyObject>.fromOpaque(cfType!).takeUnretainedValue()
        } else {
            return nil
        }
    }

    var id: String {
        return getProperty(kTISPropertyInputSourceID) as! String
    }

    var name: String {
        return getProperty(kTISPropertyLocalizedName) as! String
    }

    var category: String {
        return getProperty(kTISPropertyInputSourceCategory) as! String
    }

    var isSelectable: Bool {
        return getProperty(kTISPropertyInputSourceIsSelectCapable) as! Bool
    }

    var sourceLanguages: [String] {
        return getProperty(kTISPropertyInputSourceLanguages) as! [String]
    }

    var iconImageURL: URL? {
        return getProperty(kTISPropertyIconImageURL) as! URL?
    }

    var iconRef: IconRef? {
        return OpaquePointer(TISGetInputSourceProperty(self, kTISPropertyIconRef)) as IconRef?
    }
}

// credit: https://gist.github.com/MaciejGad/11d8469b218817290ee77012edb46608
extension NSImage {
    
    /// Returns the height of the current image.
    var height: CGFloat {
        return self.size.height
    }
    
    /// Returns the width of the current image.
    var width: CGFloat {
        return self.size.width
    }
    
    /// Returns a png representation of the current image.
    var PNGRepresentation: Data? {
        if let tiff = self.tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
            return tiffData.representation(using: .png, properties: [:])
        }
        
        return nil
    }
    
    ///  Copies the current image and resizes it to the given size.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The resized copy of the given image.
    func copy(size: NSSize) -> NSImage? {
        // Create a new rect with given width and height
        let frame = NSMakeRect(0, 0, size.width, size.height)
        
        // Get the best representation for the given size.
        guard let rep = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        
        // Create an empty image with the given size.
        let img = NSImage(size: size)
        
        // Set the drawing context and make sure to remove the focus before returning.
        img.lockFocus()
        defer { img.unlockFocus() }
        
        // Draw the new image
        if rep.draw(in: frame) {
            return img
        }
        
        // Return nil in case something went wrong.
        return nil
    }
    
    ///  Copies the current image and resizes it to the size of the given NSSize, while
    ///  maintaining the aspect ratio of the original image.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The resized copy of the given image.
    func resizeWhileMaintainingAspectRatioToSize(size: NSSize) -> NSImage? {
        let newSize: NSSize
        
        let widthRatio  = size.width / self.width
        let heightRatio = size.height / self.height
        
        if widthRatio > heightRatio {
            newSize = NSSize(width: floor(self.width * widthRatio), height: floor(self.height * widthRatio))
        } else {
            newSize = NSSize(width: floor(self.width * heightRatio), height: floor(self.height * heightRatio))
        }
        
        return self.copy(size: newSize)
    }
    
}

