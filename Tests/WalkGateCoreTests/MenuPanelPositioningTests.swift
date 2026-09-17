import CoreGraphics
import XCTest

@testable import WalkGateCore

final class MenuPanelPositioningTests: XCTestCase {
  func testPanelLeftEdgeAlignsWithStatusItem() {
    let origin = MenuPanelPositioning.origin(
      anchorFrame: CGRect(x: 700, y: 900, width: 24, height: 24),
      panelSize: CGSize(width: 320, height: 400),
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )

    XCTAssertEqual(origin.x, 700)
    XCTAssertEqual(origin.y, 496)
  }

  func testPanelStaysInsideRightScreenEdge() {
    let origin = MenuPanelPositioning.origin(
      anchorFrame: CGRect(x: 1_400, y: 900, width: 24, height: 24),
      panelSize: CGSize(width: 320, height: 400),
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )

    XCTAssertEqual(origin.x, 1_112)
  }

  func testPanelStaysInsideLeftAndBottomScreenEdges() {
    let origin = MenuPanelPositioning.origin(
      anchorFrame: CGRect(x: 0, y: 200, width: 24, height: 24),
      panelSize: CGSize(width: 320, height: 400),
      visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
    )

    XCTAssertEqual(origin.x, 8)
    XCTAssertEqual(origin.y, 8)
  }
}
