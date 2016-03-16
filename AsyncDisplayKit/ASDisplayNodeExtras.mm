/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDisplayNodeExtras.h"
#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+FrameworkPrivate.h"

extern ASInterfaceState ASInterfaceStateForDisplayNode(ASDisplayNode *displayNode, UIWindow *window)
{
    if (displayNode && [displayNode supportsRangeManagedInterfaceState]) {
        // Only use the interfaceState of nodes that are range managed
        ASInterfaceState interfaceState = displayNode.interfaceState;
        return (window == nil ? (interfaceState &= (~ASInterfaceStateVisible)) : interfaceState);
    } else {
        // For not range managed nodes we might be on our own to try to guess if we're visible.
        return (window == nil ? ASInterfaceStateNone : (ASInterfaceStateVisible | ASInterfaceStateDisplay));
    }
}

extern ASDisplayNode *ASLayerToDisplayNode(CALayer *layer)
{
  return layer.asyncdisplaykit_node;
}

extern ASDisplayNode *ASViewToDisplayNode(UIView *view)
{
  return view.asyncdisplaykit_node;
}

extern void ASDisplayNodePerformBlockOnEveryNode(CALayer *layer, ASDisplayNode *node, void(^block)(ASDisplayNode *node))
{
  if (!node) {
    ASDisplayNodeCAssertNotNil(layer, @"Cannot recursively perform with nil node and nil layer");
    ASDisplayNodeCAssertMainThread();
    node = ASLayerToDisplayNode(layer);
  }
  
  if (node) {
    block(node);
  }
  if (!layer && [node isNodeLoaded] && ASDisplayNodeThreadIsMain()) {
    layer = node.layer;
  }
  
  if (layer) {
    for (CALayer *sublayer in [layer sublayers]) {
      ASDisplayNodePerformBlockOnEveryNode(sublayer, nil, block);
    }
  } else if (node) {
    for (ASDisplayNode *subnode in [node subnodes]) {
      ASDisplayNodePerformBlockOnEveryNode(nil, subnode, block);
    }
  }
}

extern void ASDisplayNodePerformBlockOnEverySubnode(ASDisplayNode *node, void(^block)(ASDisplayNode *node))
{
  for (ASDisplayNode *subnode in node.subnodes) {
    ASDisplayNodePerformBlockOnEveryNode(nil, subnode, block);
  }
}

id ASDisplayNodeFindFirstSupernode(ASDisplayNode *node, BOOL (^block)(ASDisplayNode *node))
{
  CALayer *layer = node.layer;

  while (layer) {
    node = ASLayerToDisplayNode(layer);
    if (block(node)) {
      return node;
    }
    layer = layer.superlayer;
  }

  return nil;
}

id ASDisplayNodeFindFirstSupernodeOfClass(ASDisplayNode *start, Class c)
{
  return ASDisplayNodeFindFirstSupernode(start, ^(ASDisplayNode *n) {
    return [n isKindOfClass:c];
  });
}

static void _ASCollectDisplayNodes(NSMutableArray *array, CALayer *layer)
{
  ASDisplayNode *node = ASLayerToDisplayNode(layer);

  if (nil != node) {
    [array addObject:node];
  }

  for (CALayer *sublayer in layer.sublayers)
    _ASCollectDisplayNodes(array, sublayer);
}

extern NSArray<ASDisplayNode *> *ASCollectDisplayNodes(ASDisplayNode *node)
{
  NSMutableArray *list = [NSMutableArray array];
  for (CALayer *sublayer in node.layer.sublayers) {
    _ASCollectDisplayNodes(list, sublayer);
  }
  return list;
}

#pragma mark - Find all subnodes

static void _ASDisplayNodeFindAllSubnodes(NSMutableArray *array, ASDisplayNode *node, BOOL (^block)(ASDisplayNode *node))
{
  if (!node)
    return;

  for (ASDisplayNode *subnode in node.subnodes) {
    if (block(subnode)) {
      [array addObject:node];
    }

    _ASDisplayNodeFindAllSubnodes(array, subnode, block);
  }
}

extern NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodes(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node))
{
  NSMutableArray *list = [NSMutableArray array];
  _ASDisplayNodeFindAllSubnodes(list, start, block);
  return list;
}

extern NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodesOfClass(ASDisplayNode *start, Class c)
{
  return ASDisplayNodeFindAllSubnodes(start, ^(ASDisplayNode *n) {
    return [n isKindOfClass:c];
  });
}

#pragma mark - Find first subnode

static ASDisplayNode *_ASDisplayNodeFindFirstNode(ASDisplayNode *startNode, BOOL includeStartNode, BOOL (^block)(ASDisplayNode *node))
{
  for (ASDisplayNode *subnode in startNode.subnodes) {
    ASDisplayNode *foundNode = _ASDisplayNodeFindFirstNode(subnode, YES, block);
    if (foundNode) {
      return foundNode;
    }
  }

  if (includeStartNode && block(startNode))
    return startNode;

  return nil;
}

extern __kindof ASDisplayNode * ASDisplayNodeFindFirstNode(ASDisplayNode *startNode, BOOL (^block)(ASDisplayNode *node))
{
  return _ASDisplayNodeFindFirstNode(startNode, YES, block);
}

extern __kindof ASDisplayNode * ASDisplayNodeFindFirstSubnode(ASDisplayNode *startNode, BOOL (^block)(ASDisplayNode *node))
{
  return _ASDisplayNodeFindFirstNode(startNode, NO, block);
}

extern __kindof ASDisplayNode * ASDisplayNodeFindFirstSubnodeOfClass(ASDisplayNode *start, Class c)
{
  return ASDisplayNodeFindFirstSubnode(start, ^(ASDisplayNode *n) {
    return [n isKindOfClass:c];
  });
}

static inline BOOL _ASDisplayNodeIsAncestorOfDisplayNode(ASDisplayNode *possibleAncestor, ASDisplayNode *possibleDescendent)
{
  ASDisplayNode *supernode = possibleDescendent;
  while (supernode) {
    if (supernode == possibleAncestor) {
      return YES;
    }
    supernode = supernode.supernode;
  }
  
  return NO;
}

extern ASDisplayNode *ASDisplayNodeFindClosestCommonAncestor(ASDisplayNode *node1, ASDisplayNode *node2)
{
  ASDisplayNode *possibleAncestor = node1;
  while (possibleAncestor) {
    if (_ASDisplayNodeIsAncestorOfDisplayNode(possibleAncestor, node2)) {
      break;
    }
    possibleAncestor = possibleAncestor.supernode;
  }
  
  ASDisplayNodeCAssertNotNil(possibleAncestor, @"Could not find a common ancestor between node1: %@ and node2: %@", node1, node2);
  return possibleAncestor;
}

extern ASDisplayNode *ASDisplayNodeUltimateParentOfNode(ASDisplayNode *node)
{
  // node <- supernode on each loop
  // previous <- node on each loop where node is not nil
  // previous is the final non-nil value of supernode, i.e. the root node
  ASDisplayNode *previousNode = node;
  while ((node = [node supernode])) {
    previousNode = node;
  }
  return previousNode;
}

#pragma mark - Placeholders

UIColor *ASDisplayNodeDefaultPlaceholderColor()
{
  static UIColor *defaultPlaceholderColor;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultPlaceholderColor = [UIColor colorWithWhite:0.95 alpha:1.0];
  });
  return defaultPlaceholderColor;
}

UIColor *ASDisplayNodeDefaultTintColor()
{
  static UIColor *defaultTintColor;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultTintColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
  });
  return defaultTintColor;
}

#pragma mark - Hierarchy Notifications

void ASDisplayNodeDisableHierarchyNotifications(ASDisplayNode *node)
{
  [node __incrementVisibilityNotificationsDisabled];
}

void ASDisplayNodeEnableHierarchyNotifications(ASDisplayNode *node)
{
  [node __decrementVisibilityNotificationsDisabled];
}
