import Foundation
import UIKit

@available(iOSApplicationExtension 10.0, *)
private final class HapticFeedbackImpl {
    private lazy var impactGenerator = { UIImpactFeedbackGenerator(style: .light) }()
    private lazy var selectionGenerator = { UISelectionFeedbackGenerator() }()
    private lazy var notificationGenerator = { UINotificationFeedbackGenerator() }()
    
    func prepareTap() {
        self.selectionGenerator.prepare()
    }
    
    func tap() {
        self.selectionGenerator.selectionChanged()
    }
    
    func success() {
        self.notificationGenerator.notificationOccurred(.success)
    }
    
    func error() {
        self.notificationGenerator.notificationOccurred(.error)
    }
    
    dynamic func f() {
    }
}

final class HapticFeedback {
    private var impl: AnyObject?
    
    deinit {
        let impl = self.impl
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
            if #available(iOSApplicationExtension 10.0, *) {
                if let impl = impl as? HapticFeedbackImpl {
                    impl.f()
                }
            }
        })
    }
    
    @available(iOSApplicationExtension 10.0, *)
    private func withImpl(_ f: (HapticFeedbackImpl) -> Void) {
        if self.impl == nil {
            self.impl = HapticFeedbackImpl()
        }
        f(self.impl as! HapticFeedbackImpl)
    }
    
    func prepareTap() {
        if #available(iOSApplicationExtension 10.0, *) {
            self.withImpl { impl in
                impl.prepareTap()
            }
        }
    }
    
    func tap() {
        if #available(iOSApplicationExtension 10.0, *) {
            self.withImpl { impl in
                impl.tap()
            }
        }
    }
    
    func success() {
        if #available(iOSApplicationExtension 10.0, *) {
            self.withImpl { impl in
                impl.success()
            }
        }
    }
    
    func error() {
        if #available(iOSApplicationExtension 10.0, *) {
            self.withImpl { impl in
                impl.error()
            }
        }
    }
}
