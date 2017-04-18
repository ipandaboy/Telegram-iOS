import Foundation
import UIKit
import AVFoundation
import SwiftSignalKit

private final class SampleBufferLayerImpl: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }
}

final class SampleBufferLayer {
    let layer: AVSampleBufferDisplayLayer
    private let enqueue: (AVSampleBufferDisplayLayer) -> Void
    
    fileprivate init(layer: AVSampleBufferDisplayLayer, enqueue: @escaping (AVSampleBufferDisplayLayer) -> Void) {
        self.layer = layer
        self.enqueue = enqueue
    }
    
    deinit {
        self.enqueue(self.layer)
    }
}

private let pool = Atomic<[AVSampleBufferDisplayLayer]>(value: [])

func takeSampleBufferLayer() -> SampleBufferLayer {
    var layer: AVSampleBufferDisplayLayer?
    let _ = pool.modify { list in
        var list = list
        if !list.isEmpty {
            layer = list.removeLast()
        }
        return list
    }
    if layer == nil {
        layer = SampleBufferLayerImpl()
    }
    return SampleBufferLayer(layer: layer!, enqueue: { layer in
        Queue.concurrentDefaultQueue().async {
            layer.flushAndRemoveImage()
            let _ = pool.modify { list in
                var list = list
                list.append(layer)
                return list
            }
        }
    })
}
