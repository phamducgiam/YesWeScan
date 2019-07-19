import CoreGraphics

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x,
                       y: lhs.y + rhs.y)
    }

    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs // swiftlint:disable:this shorthand_operator
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x,
                       y: lhs.y - rhs.y)
    }

    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs,
                       y: lhs.y / rhs)
    }
}

func abs(_ point: CGPoint) -> CGFloat {
    return abs(point.x) + abs(point.y)
}

func distance(point1: CGPoint, point2: CGPoint) -> CGFloat {
    let dx = point1.x - point2.x
    let dy = point1.y - point2.y
    return sqrt(dx * dx + dy * dy)
}

/**
 * calculate area of triangle
 */
func area(point1: CGPoint, point2: CGPoint, point3: CGPoint) -> CGFloat {
    let a = distance(point1: point1, point2: point2)
    let b = distance(point1: point2, point2: point3)
    let c = distance(point1: point3, point2: point1)
    let result = (a + b + c) * (a + b - c) * (b + c - a) * (c + a - b)
    return 0.25 * sqrt(result)
}

/**
 * calculate area of quadrilateral
 */
func area(point1: CGPoint, point2: CGPoint, point3: CGPoint, point4: CGPoint) -> CGFloat {
    let a = distance(point1: point1, point2: point2)
    let b = distance(point1: point2, point2: point3)
    let c = distance(point1: point3, point2: point4)
    let d = distance(point1: point4, point2: point1)
    let f = distance(point1: point1, point2: point3)
    let r1 = (a + b + f) * (a + b - f) * (b + f - a) * (f + a - b)
    let r2 = (c + d + f) * (c + d - f) * (d + f - c) * (f + c - d)
    return 0.25 * (sqrt(r1) + sqrt(r2))
}

extension RectangleFeature {
    static func + (lhs: RectangleFeature, rhs: RectangleFeature) -> RectangleFeature {
        return RectangleFeature(topLeft: lhs.topLeft + rhs.topLeft,
                                topRight: lhs.topRight + rhs.topRight,
                                bottomLeft: lhs.bottomLeft + rhs.bottomLeft,
                                bottomRight: lhs.bottomRight + rhs.bottomRight)
    }

    static func / (lhs: RectangleFeature, rhs: CGFloat) -> RectangleFeature {
        return RectangleFeature(topLeft: lhs.topLeft / rhs,
                                topRight: lhs.topRight / rhs,
                                bottomLeft: lhs.bottomLeft / rhs,
                                bottomRight: lhs.bottomRight / rhs)
    }
}
