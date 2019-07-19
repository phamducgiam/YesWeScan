import UIKit

public struct RectangleFeature {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    var accuracy: String?

    init(topLeft: CGPoint = .zero,
         topRight: CGPoint = .zero,
         bottomLeft: CGPoint = .zero,
         bottomRight: CGPoint = .zero) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

extension RectangleFeature {
    init(_ rectangleFeature: CIRectangleFeature) {
        topLeft = rectangleFeature.topLeft
        topRight = rectangleFeature.topRight
        bottomLeft = rectangleFeature.bottomLeft
        bottomRight = rectangleFeature.bottomRight
    }

    func smoothed(with previous: [RectangleFeature]) -> (RectangleFeature, [RectangleFeature]) {

        let allFeatures = [self] + previous
        let smoothed = allFeatures.average

        return (smoothed, Array(allFeatures.prefix(10)))
    }

    func normalized(source: CGSize, target: CGSize) -> RectangleFeature {
        // Since the source and target sizes have different aspect ratios,
        // source must be normalized. It behaves like
        // `UIView.ContentMode.aspectFill`, truncating portions that don't fit
        let normalizedSource = CGSize(width: source.height * target.aspectRatio,
                                      height: source.height)
        let xShift = (normalizedSource.width - source.width) / 2
        let yShift = (normalizedSource.height - source.height) / 2

        let distortion = CGVector(dx: target.width / normalizedSource.width,
                                  dy: target.height / normalizedSource.height)

        func normalize(_ point: CGPoint) -> CGPoint {
            return point
                .yAxisInverted(source.height)
                .shifted(by: CGPoint(x: xShift, y: yShift))
                .distorted(by: distortion)
        }

        return RectangleFeature(
            topLeft: normalize(topLeft),
            topRight: normalize(topRight),
            bottomLeft: normalize(bottomLeft),
            bottomRight: normalize(bottomRight)
        )
    }

    public var bezierPath: UIBezierPath {

        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()

        return path
    }

    func difference(to: RectangleFeature) -> CGFloat {
            return
                abs(to.topLeft - topLeft) +
                abs(to.topRight - topRight) +
                abs(to.bottomLeft - bottomLeft) +
                abs(to.bottomRight - bottomRight)
    }
    
    func area() -> CGFloat {
        return re2demo.area(point1: topLeft, point2: topRight, point3: bottomRight, point4: bottomLeft)
    }
    
    mutating func calculateAccuracy() {
        let a = distance(point1: topLeft, point2: topRight)
        let b = distance(point1: topRight, point2: bottomRight)
        let c = distance(point1: bottomRight, point2: bottomLeft)
        let d = distance(point1: bottomLeft, point2: topLeft)
        let mpi2 = CGFloat.pi / 2
        var rate = CGFloat(1.0)
        var angle = acos(((topLeft.x - topRight.x) * (bottomRight.x - topRight.x) + (topLeft.y - topRight.y) * (bottomRight.y - topRight.y)) / (a * b))
        rate *= angle < mpi2 ? angle / mpi2 : mpi2 / angle
        angle = acos(((topRight.x - bottomRight.x) * (bottomLeft.x - bottomRight.x) + (topRight.y - bottomRight.y) * (bottomLeft.y - bottomRight.y)) / (b * c))
        rate *= angle < mpi2 ? angle / mpi2 : mpi2 / angle
        angle = acos(((bottomRight.x - bottomLeft.x) * (topLeft.x - bottomLeft.x) + (bottomRight.y - bottomLeft.y) * (topLeft.y - bottomLeft.y)) / (c * d))
        rate *= angle < mpi2 ? angle / mpi2 : mpi2 / angle
        angle = acos(((topRight.x - topLeft.x) * (bottomLeft.x - topLeft.x) + (topRight.y - topLeft.y) * (bottomLeft.y - topLeft.y)) / (d * a))
        rate *= angle < mpi2 ? angle / mpi2 : mpi2 / angle
        print("rectange rate: \(rate)")
        if rate < 0.9 {
            self.accuracy = "Hold straight"
            return
        }
        
        let e = distance(point1: topRight, point2: bottomLeft)
        let f = distance(point1: topLeft, point2: bottomRight)
        /*let area1 = (a + b + f) * (a + b - f) * (b + f - a) * (f + a - b)
        let area2 = (c + d + f) * (c + d - f) * (d + f - c) * (f + c - d)
        let area = 0.25 * (sqrt(area1) + sqrt(area2))*/
        let t = b * b + d * d - a * a - c * c
        let area = 0.25 * sqrt(4 * e * e * f * f - t * t)
        let screenSize = UIScreen.main.bounds.size
        let screenArea = screenSize.width * screenSize.height
        let ratio = area / screenArea
        print("rectangle topLeft: \(topLeft), topRight: \(topRight), bottomRight: \(bottomRight), bottomLeft: \(bottomLeft); rectange area: \(area); screen size: \(screenSize); screen area: \(screenArea); ratio: \(ratio)")
        if ratio < 0.4 {
            self.accuracy = "Move closer"
            return
        }
        
        self.accuracy = nil
    }

    /// This isn't the real area, but enables correct comparison
    private var areaQualifier: CGFloat {
        let diagonalToLeft = (topRight - bottomLeft)
        let diagonalToRight = (topLeft - bottomRight)
        let phi = diagonalToLeft.x * diagonalToRight.x
            + diagonalToLeft.y * diagonalToRight.y
            / (diagonalToLeft.length * diagonalToRight.length)
        return sqrt(1 - phi * phi) * diagonalToLeft.length * diagonalToRight.length
    }
}

extension RectangleFeature: Comparable {
    public static func < (lhs: RectangleFeature, rhs: RectangleFeature) -> Bool {
        return lhs.areaQualifier < rhs.areaQualifier
    }

    public static func == (lhs: RectangleFeature, rhs: RectangleFeature) -> Bool {
        return lhs.topLeft == rhs.topLeft
            && lhs.topRight == rhs.topRight
            && lhs.bottomLeft == rhs.bottomLeft
            && lhs.bottomRight == rhs.bottomRight
    }
}

private extension CGSize {
    var aspectRatio: CGFloat {
        return width / height
    }
}

private extension CGPoint {
    func distorted(by distortion: CGVector) -> CGPoint {
        return CGPoint(x: x * distortion.dx, y: y * distortion.dy)
    }

    func yAxisInverted(_ maxY: CGFloat) -> CGPoint {
        return CGPoint(x: x, y: maxY - y)
    }

    func shifted(by shiftAmount: CGPoint) -> CGPoint {
        return CGPoint(x: x + shiftAmount.x, y: y + shiftAmount.y)
    }

    var length: CGFloat {
        return sqrt(x * x + y * y)
    }
}
