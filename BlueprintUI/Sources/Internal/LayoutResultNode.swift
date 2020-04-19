import UIKit

extension Element {

    /// Build a fully laid out element tree with complete layout attributes
    /// for each element.
    ///
    /// - Parameter layoutAttributes: The layout attributes to assign to the
    ///   root element.
    ///
    /// - Returns: A layout result
    func layout(layoutAttributes: LayoutAttributes) -> LayoutResultNode {
        return LayoutResultNode(
            element: self,
            layoutAttributes: layoutAttributes,
            content: content)
    }

    /// Build a fully laid out element tree with complete layout attributes
    /// for each element.
    ///
    /// - Parameter frame: The frame to assign to the root element.
    ///
    /// - Returns: A layout result
    func layout(frame: CGRect) -> LayoutResultNode {
        return layout(layoutAttributes: LayoutAttributes(frame: frame))
    }

}

/// Represents a tree of elements with complete layout attributes
struct LayoutResultNode {
    
    /// The element that was laid out
    var element: Element
    
    /// Diagnostic information about the layout process.
    var diagnosticInfo: DiagnosticInfo
    
    /// The layout attributes for the element
    var layoutAttributes: LayoutAttributes

    /// The element's children.
    var children: [(identifier: ElementIdentifier, node: LayoutResultNode)]
    
    init(element: Element, layoutAttributes: LayoutAttributes, content: ElementContent) {

        self.element = element
        self.layoutAttributes = layoutAttributes

        let layoutBeginTime = DispatchTime.now()
        children = content.performLayout(attributes: layoutAttributes)
        let layoutEndTime = DispatchTime.now()
        let layoutDuration = layoutEndTime.uptimeNanoseconds - layoutBeginTime.uptimeNanoseconds
        diagnosticInfo = LayoutResultNode.DiagnosticInfo(layoutDuration: layoutDuration)

    }

}

extension LayoutResultNode {
    
    struct DiagnosticInfo {
        
        var layoutDuration: UInt64
        
        init(layoutDuration: UInt64) {
            self.layoutDuration = layoutDuration
        }
    }
    
}

extension LayoutResultNode {

    /// Returns the flattened tree of view descriptions (any element that does not return
    /// a view description will be skipped).
    func resolve(debugging : Debugging = Debugging()) -> [(path: ElementPath, node: NativeViewNode)] {

        let resolvedChildContent: [(path: ElementPath, node: NativeViewNode)] = children
            .flatMap { identifier, layoutResultNode in

                return layoutResultNode
                    .resolve(debugging: debugging)
                    .map { path, viewDescriptionNode in
                        return (path: path.prepending(identifier: identifier), node: viewDescriptionNode)
                    }
        }

        let subtreeExtent: CGRect? = children
            .map { $0.node }
            .reduce(into: nil) { (rect, node) in
                rect = rect?.union(node.layoutAttributes.frame) ?? node.layoutAttributes.frame
            }

        let viewDescription = self.viewDescriptionForDisplay(
            subtreeExtent: subtreeExtent,
            debugging: debugging
        )

        if let viewDescription = viewDescription {
            let node = NativeViewNode(
                content: viewDescription,
                layoutAttributes: layoutAttributes,
                children: resolvedChildContent
            )
            return [(path: .empty, node: node)]
        } else {
            return resolvedChildContent.map { (path, node) -> (path: ElementPath, node: NativeViewNode) in
                var transformedNode = node
                transformedNode.layoutAttributes = transformedNode.layoutAttributes.within(layoutAttributes)
                return (path, transformedNode)
            }
        }

    }
    
    func viewDescriptionForDisplay(subtreeExtent : CGRect?, debugging : Debugging) -> ViewDescription? {
        
        let original = self.element.backingViewDescription(
            bounds: self.layoutAttributes.bounds,
            subtreeExtent: subtreeExtent
        )
        
        switch debugging.showElementFrames {
        case .none:
            return original
            
        case .all:
            return Debugging.viewDescriptionWrapping(
                other: original,
                for: self.element,
                bounds: self.layoutAttributes.bounds
            )
            
        case .viewBacked:
            if original != nil {
                return Debugging.viewDescriptionWrapping(
                    other: original,
                    for: self.element,
                    bounds: self.layoutAttributes.bounds
                )
            } else {
                return nil
            }
        }
    }
    
}
