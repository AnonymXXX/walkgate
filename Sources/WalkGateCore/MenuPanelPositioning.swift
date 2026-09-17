import CoreGraphics

public enum MenuPanelPositioning {
  public static func origin(
    anchorFrame: CGRect,
    panelSize: CGSize,
    visibleFrame: CGRect,
    edgeInset: CGFloat = 8,
    verticalGap: CGFloat = 4
  ) -> CGPoint {
    let minimumX = visibleFrame.minX + edgeInset
    let maximumX = max(visibleFrame.maxX - panelSize.width - edgeInset, minimumX)
    let alignedX = anchorFrame.minX
    let x = min(max(alignedX, minimumX), maximumX)

    let minimumY = visibleFrame.minY + edgeInset
    let y = max(anchorFrame.minY - panelSize.height - verticalGap, minimumY)
    return CGPoint(x: x, y: y)
  }
}
