import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

final class PeerInfoPeerItem: ListViewItem, PeerInfoItem {
    let account: Account
    let peer: Peer?
    let presence: PeerPresence?
    let label: String?
    let sectionId: PeerInfoItemSectionId
    let action: () -> Void
    
    init(account: Account, peer: Peer?, presence: PeerPresence?, label: String?, sectionId: PeerInfoItemSectionId, action: @escaping () -> Void) {
        self.account = account
        self.peer = peer
        self.presence = presence
        self.label = label
        self.sectionId = sectionId
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = PeerInfoPeerItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply()
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? PeerInfoPeerItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)
private let titleBoldFont = Font.medium(17.0)
private let statusFont = Font.regular(14.0)
private let labelFont = Font.regular(13.0)
private let avatarFont = Font.regular(17.0)

class PeerInfoPeerItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let statusNode: TextNode
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (PeerInfoPeerItem, CGFloat, PeerInfoItemNeighbors)?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.bottomStripeNode.isLayerBacked = true
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.labelNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2)
                apply()
            }
        })
    }
    
    func asyncLayout() -> (_ item: PeerInfoPeerItem, _ width: CGFloat, _ neighbors: PeerInfoItemNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, width, neighbors in
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var labelAttributedString: NSAttributedString?
            
            if let peer = item.peer {
                if let user = peer as? TelegramUser {
                    if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: .black))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: .black))
                        string.append(NSAttributedString(string: lastName, font: titleBoldFont, textColor: .black))
                        titleAttributedString = string
                    } else if let firstName = user.firstName, !firstName.isEmpty {
                        titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: UIColor.black)
                    } else if let lastName = user.lastName, !lastName.isEmpty {
                        titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: UIColor.black)
                    } else {
                        titleAttributedString = NSAttributedString(string: "Deleted User", font: titleBoldFont, textColor: UIColor(0xa6a6a6))
                    }
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        let (string, activity) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                        statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? UIColor(0x007ee5) : UIColor(0xa6a6a6))
                    } else {
                        statusAttributedString = NSAttributedString(string: "last seen recently", font: statusFont, textColor: UIColor(0xa6a6a6))
                    }
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: UIColor.black)
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: UIColor.black)
                }
            }
            
            if let label = item.label {
                labelAttributedString = NSAttributedString(string: label, font: labelFont, textColor: UIColor(0xa6a6a6))
            }
            
            let leftInset: CGFloat = 65.0
            
            let (labelLayout, labelApply) = makeLabelLayout(labelAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - labelLayout.size.width, height: CGFloat.greatestFiniteMagnitude), nil)
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - (labelLayout.size.width > 0.0 ? (labelLayout.size.width) + 15.0 : 0.0), height: CGFloat.greatestFiniteMagnitude), nil)
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: width, height: 48.0)
            let topInset: CGFloat
            let bottomInset: CGFloat
            switch neighbors.top {
                case .sameSection, .none:
                    topInset = 0.0
                case .otherSection:
                    topInset = separatorHeight + 35.0
            }
            switch neighbors.bottom {
                case .none:
                    bottomInset = separatorHeight + 35.0
                case .otherSection, .sameSection:
                    bottomInset = separatorHeight
            }
            insets = UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, width, neighbors)
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    let _ = labelApply()
                    
                    strongSelf.labelNode.isHidden = labelAttributedString == nil
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                        case .sameSection:
                            strongSelf.topStripeNode.isHidden = true
                        case .none, .otherSection:
                            strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection:
                            bottomStripeInset = leftInset
                        case .none, .otherSection:
                            bottomStripeInset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 5.0), size: titleLayout.size)
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 25.0), size: statusLayout.size)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: width - labelLayout.size.width - 15.0, y: floor((contentSize.height - labelLayout.size.height) / 2.0 - labelLayout.size.height / 10.0)), size: labelLayout.size)
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0))
                    if let peer = item.peer {
                        strongSelf.avatarNode.setPeer(account: item.account, peer: peer)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 48.0 + UIScreenPixel + UIScreenPixel))
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.topStripeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.bottomStripeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.topStripeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.bottomStripeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.titleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.labelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
    }
}
