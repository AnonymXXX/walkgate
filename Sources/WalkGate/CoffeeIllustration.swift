import SwiftUI

struct CoffeeIllustration: View {
  var body: some View {
    Canvas { context, size in
      let scale = size.width / 52
      context.scaleBy(x: scale, y: size.height / 58)
      var handle = Path()
      handle.addRoundedRect(
        in: CGRect(x: 34, y: 32, width: 11, height: 13), cornerSize: CGSize(width: 6, height: 6))
      context.stroke(handle, with: .color(Color(red: 0.7, green: 0.83, blue: 1)), lineWidth: 3)
      var cup = Path()
      cup.move(to: CGPoint(x: 5, y: 27))
      cup.addLine(to: CGPoint(x: 37, y: 27))
      cup.addLine(to: CGPoint(x: 37, y: 41))
      cup.addQuadCurve(to: CGPoint(x: 21, y: 55), control: CGPoint(x: 37, y: 55))
      cup.addQuadCurve(to: CGPoint(x: 5, y: 41), control: CGPoint(x: 5, y: 55))
      cup.closeSubpath()
      context.fill(
        cup,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 0.29, green: 0.57, blue: 1), Color(red: 0.13, green: 0.4, blue: 1),
          ]), startPoint: CGPoint(x: 5, y: 27), endPoint: CGPoint(x: 37, y: 55)))
      context.stroke(
        cup, with: .color(Color(red: 0.87, green: 0.94, blue: 1)),
        style: StrokeStyle(lineWidth: 3, lineJoin: .round))
      for x in [17.0, 28.0] {
        var steam = Path()
        steam.move(to: CGPoint(x: x, y: 18))
        steam.addCurve(
          to: CGPoint(x: x - 1, y: 3), control1: CGPoint(x: x + 6, y: 12),
          control2: CGPoint(x: x - 5, y: 9))
        context.stroke(
          steam, with: .color(Color(red: 0.32, green: 0.63, blue: 1)),
          style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
      }
    }
    .accessibilityHidden(true)
  }
}

struct WalkActionStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white)
      .background {
        Capsule().fill(
          LinearGradient(
            colors: [
              Color(red: 0.13, green: 0.59, blue: 1), Color(red: 0, green: 0.43, blue: 0.98),
            ], startPoint: .top, endPoint: .bottom))
      }
      .overlay { Capsule().strokeBorder(.white.opacity(0.24), lineWidth: 1) }
      .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
      .contentShape(Capsule())
  }
}
