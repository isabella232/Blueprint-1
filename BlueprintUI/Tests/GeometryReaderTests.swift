import XCTest
@testable import BlueprintUI

final class GeometryReaderTests: XCTestCase {

    func test_measuring() {
        let constrainedSize = CGSize(width: 100, height: 100)
        let unconstrainedSize = CGSize(width: 200, height: 200)

        let element = GeometryReader { (geometry) -> Element in
            if geometry.constraint.width.isConstrained {
                return Spacer(size: constrainedSize)
            } else {
                return Spacer(size: unconstrainedSize)
            }
        }

        XCTAssertEqual(
            element.content.measure(in: .unconstrained),
            unconstrainedSize
        )

        XCTAssertEqual(
            element.content.measure(in: SizeConstraint(.zero)),
            constrainedSize
        )
    }

    func test_layout() {
        let element = GeometryReader { (geometry) -> Element in
            // Create an element with half the dimensions of the available size,
            // aligned in the bottom right.

            let width = geometry.constraint.maximum.width / 2.0
            let height = geometry.constraint.maximum.height / 2.0

            return Spacer(width: width, height: height)
                .aligned(vertically: .bottom, horizontally: .trailing)
        }

        /// Walk a node tree down each node's first child and return the frame of the first leaf node.
        func leafChildFrame(in node: LayoutResultNode) -> CGRect {
            if let childNode = node.children.first?.node {
                return leafChildFrame(in: childNode)
            }
            return node.layoutAttributes.frame
        }

        let layoutResultNode = element.layout(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let frame = leafChildFrame(in: layoutResultNode)
        XCTAssertEqual(frame, CGRect(x: 50, y: 50, width: 50, height: 50))
    }
}

private extension SizeConstraint.Axis {
    var isConstrained: Bool {
        switch self {
        case .atMost:
            return true
        case .unconstrained:
            return false
        }
    }
}
