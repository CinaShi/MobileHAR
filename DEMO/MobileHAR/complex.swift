//
// Simple Complex struct, compatible with Swift 3.
//
import CoreGraphics

public struct Complex: CustomStringConvertible, Equatable, Hashable {
    public var real, imag: Double

    public init(_ real: Double, _ imag: Double) {
        self.real = real
        self.imag = imag
    }
    
    // Extra initializer instead of having the first one take two defaults, just for conformance
    // with protocols which expect an initializer from a single Double value. In current Swift, an initializer
    // with a default value for the second parameter isn't recognized by such a protocol.
    public init(_ real: Double = 0.0) {
        self.real = real
        self.imag = 0.0
    }
    public init(abs: Double, arg: Double) {
        self.real = abs * _cos(arg)
        self.imag = abs * _sin(arg)
    }

    public var abs: Double { return hypot(real, imag) }
    public var arg: Double { return atan2(imag, real) }
    public var norm: Double { return real*real + imag*imag }
    public var conj: Complex { return Complex(real, -imag) }

    public var description: String {
        let sign = (imag.sign == .minus) ? "-" : "+"
        return "\(real)\(sign)\(imag)i"
    }

    public var hashValue: Int {
        return real.hashValue ^ imag.hashValue
    }
}

public func == (lhs: Complex, rhs: Complex) -> Bool {
    return lhs.real == rhs.real && lhs.imag == rhs.imag
}
public func == (lhs: Complex, rhs: Double) -> Bool {
    return lhs == Complex(rhs)
}
public func == (lhs: Double, rhs: Complex) -> Bool {
    return rhs == lhs
}
public func != (lhs: Complex, rhs: Double) -> Bool {
    return !(lhs == rhs)
}
public func != (lhs: Double, rhs: Complex) -> Bool {
    return !(lhs == rhs)
}

public prefix func + (z: Complex) -> Complex {
    return z
}
public func + (lhs: Complex, rhs: Complex) -> Complex {
    return Complex(lhs.real + rhs.real, lhs.imag + rhs.imag)
}
public func + (lhs: Complex, rhs: Double) -> Complex {
    return lhs + Complex(rhs)
}
public func + (lhs: Double, rhs: Complex) -> Complex {
    return rhs + lhs
}
public func += (lhs: inout Complex, rhs: Complex) {
    lhs = lhs + rhs
}
public func += (lhs: inout Complex, rhs: Double) {
    lhs = lhs + rhs
}

public prefix func - (z: Complex) -> Complex {
    return 0.0 - z
}
public func - (lhs: Complex, rhs: Complex) -> Complex {
    return Complex(lhs.real - rhs.real, lhs.imag - rhs.imag)
}
public func - (lhs: Complex, rhs: Double) -> Complex {
    return lhs - Complex(rhs)
}
public func - (lhs: Double, rhs: Complex) -> Complex {
    return Complex(lhs) - rhs
}
public func -= (lhs: inout Complex, rhs: Complex) {
    lhs = lhs - rhs
}
public func -= (lhs: inout Complex, rhs: Double) {
    lhs = lhs - rhs
}

public func * (lhs: Complex, rhs: Complex) -> Complex {
    return Complex(
        lhs.real * rhs.real - lhs.imag * rhs.imag,
        lhs.real * rhs.imag + lhs.imag * rhs.real
    )
}
public func * (lhs: Complex, rhs: Double) -> Complex {
    return lhs * Complex(rhs)
}
public func * (lhs: Double, rhs: Complex) -> Complex {
    return rhs * lhs
}
public func *= (lhs: inout Complex, rhs: Complex) {
    lhs = lhs * rhs
}
public func *= (lhs: inout Complex, rhs: Double) {
    lhs = lhs * rhs
}

public func / (lhs: Complex, rhs: Complex) -> Complex {
    return (lhs * rhs.conj) / rhs.norm
}
public func / (lhs: Complex, rhs: Double) -> Complex {
    return Complex(lhs.real / rhs, lhs.imag / rhs)
}
public func / (lhs: Double, rhs: Complex) -> Complex {
    return Complex(lhs) / rhs
}
public func /= (lhs:inout Complex, rhs: Complex) {
    lhs = lhs / rhs
}
public func /= (lhs:inout Complex, rhs: Double) {
    lhs = lhs / rhs
}

public func exp(_ z: Complex) -> Complex {
    let phase = z.imag
    return _exp(z.real) * Complex(_cos(phase), _sin(phase))
}
public func log(_ z: Complex) -> Complex {
    return Complex(log(z.abs), z.arg)
}

public func pow(_ lhs: Complex, _ rhs: Complex) -> Complex {
    return exp(log(lhs) * rhs)
}
public func pow(_ lhs: Complex, _ rhs: Double) -> Complex {
    return pow(lhs, Complex(rhs))
}
public func pow(_ lhs: Double, _ rhs: Complex) -> Complex {
    return pow(Complex(lhs), rhs)
}

extension Double {
    public var i: Complex { return Complex(0.0, self) }
}
