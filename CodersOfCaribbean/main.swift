//
//  main.swift
//  CodersOfCaribbean
//
//  Created by Svyatoshenko "Megal" Misha on 2017-04-15.
//  Copyright © 2017 Megal. All rights reserved.
//

import Foundation

// ---
// MARK: - Pipe-forward Operator
// ---

precedencegroup PipeForwardPrecedence {
	higherThan: MultiplicationPrecedence
	assignment: true
}
infix operator |> : PipeForwardPrecedence

/// Pipe-forward Operator
/// arg|>transform is equivalent to transform(arg)
public func |> <U, V>(arg: U, transform: (U) -> V ) -> V {
	return transform(arg)
}

// ---
// Compatibility fix for abs
// ---
public func myabs<T : SignedNumber>(_ x: T) -> T {

	return (x > 0)
		? x
		: -x
}

// MARK: - Logging stuff
public struct StderrOutputStream: TextOutputStream {
	public mutating func write(_ string: String) { fputs(string, stderr) }
}
public var errStream = StderrOutputStream()

var loggingEnabled = true
func log(_ message: String) {

	if loggingEnabled {
		print(message, to: &errStream)
	}
}
func fatal(_ message: String = "Fatal error!") -> Never  { log(message); abort() }

// ---
// MARK: - Cartesian 2d
// ---
typealias Int2d = (x: Int, y: Int)

func +(a: Int2d, b: Int2d) -> Int2d { return (a.x+b.x, a.y+b.y) }
func -(a: Int2d, b: Int2d) -> Int2d { return (a.x-b.x, a.y-b.y) }

// ---
// MARK: - Hexagonal 2d represented in cube coordinate form
// ---
struct Hex2d {

	var cube: (x: Int, y: Int, z: Int)

	enum Direction: Int {
		case right = 0
		case upright
		case upleft
		case left
		case downleft
		case downright
	}

	static func direction(_ direction: Direction) -> Hex2d {

		switch direction {
			case .right: return Hex2d(x: 1, y: -1, z: 0)
			case .upright: return Hex2d(x: 1, y: 0, z: -1)
			case .upleft: return Hex2d(x: 0, y: 1, z: -1)
			case .left: return Hex2d(x: -1, y: 1, z: 0)
			case .downleft: return Hex2d(x: -1, y: 0, z: 1)
			case .downright: return Hex2d(x: 0, y: -1, z: 1)
		}
	}

	static func direction(index: Int) -> Hex2d {
		precondition(0..<6 ~= index, "Should be in range");

		return direction(Direction(rawValue: index)!)
	}


	init(x: Int, y: Int, z: Int) {
		cube.x = x
		cube.y = y
		cube.z = z
	}

	init(_ int2d: Int2d) {
		cube.x = int2d.x - (int2d.y - (int2d.y & 1)) / 2
		cube.z = int2d.y
		cube.y = -(cube.x + cube.z)
	}

	/// Convert to offset coordinates
	var int2d: Int2d {
		let offsetX = x + (z - (z & 1)) / 2
		let offsetY = z
		return (x: offsetX, y: offsetY)
	}

	var x: Int {
		get { return cube.x }
		set { cube.x = newValue }
	}

	var y: Int {
		get { return cube.y }
		set { cube.y = newValue }
	}

	var z: Int {
		get { return cube.z }
		set { cube.z = newValue }
	}

	func multiplied(by scalar: Int) -> Hex2d {

		return Hex2d(
			x: x * scalar,
			y: y * scalar,
			z: z * scalar)
	}

	func adding(_ other: Hex2d) -> Hex2d {

		return Hex2d(
			x: x + other.x,
			y: y + other.y,
			z: z + other.z)
	}

	func distance(to: Hex2d) -> Int {

		return (myabs(x - to.x) + myabs(y - to.y) + myabs(z - to.z)) / 2
	}
}

func *(vec: Hex2d, scalar: Int) -> Hex2d {
	return vec.multiplied(by: scalar)
}

func +(lhs: Hex2d, rhs: Hex2d) -> Hex2d {
	return lhs.adding(rhs)
}



// ---
// MARK: - Random helpers
// ---

/// xorshift128+ PRNG
func xorshift128plus(seed0 : UInt64, seed1 : UInt64) -> () -> UInt64 {
	var s0 = seed0
	var s1 = seed1
	if s0 == 0 && s1 == 0 {
		s1 =  1 // The state must be seeded so that it is not everywhere zero.
	}

	return {
		var x = s0
		let y = s1
		s0 = y
		x ^= x << 23
		x ^= x >> 17
		x ^= y
		x ^= y >> 26
		s1 = x
		return s0 &+ s1
	}

}

struct Random {

	let generator = xorshift128plus(seed0: 0xDEAD_177EA7_15_1_1, seed1: 0x1234_0978_ABCD_CDAA)

	func bounded(to max: UInt64) -> UInt64 {
		var u: UInt64 = 0
		let b: UInt64 = (u &- max) % max
		repeat {
			u = generator()
		} while u < b
		return u % max
	}

	/// Random value for `Int` in arbitrary closed range, uniformally distributed
	subscript(range: CountableClosedRange<Int>) -> Int {
		let bound = range.upperBound.toIntMax() - range.lowerBound.toIntMax() + 1
		let x = range.lowerBound + Int(bounded(to: UInt64(bound)))

		guard range.contains(x) else { fatal("out of range") }
		return x
	}

	/// Random value for `Double` in arbitrary closed range
	subscript(range: ClosedRange<Double>) -> Double {
		let step = (range.upperBound - range.lowerBound) / Double(UInt64.max)

		let value = range.lowerBound + step*Double(generator())
		guard range.contains(value) else { fatal("out of range") }

		return value
	}

	/// Random value for `Double` in arbitrary half-open range
	subscript(range: Range<Double>) -> Double {
		let step = (range.upperBound - range.lowerBound) / (1.0 + Double(UInt64.max))

		let value = range.lowerBound + step*Double(generator())
		guard range.contains(value) else { fatal("out of range") }

		return value
	}

}

let random = Random()


// ---
// MARK: - Array extension
// ---
extension Array  {

	/// Converts Array [a, b, c, ...] to Dictionary [0:a, 1:b, 2:c, ...]
	var indexedDictionary: [Int: Element] {
		var result: [Int: Element] = [:]
		enumerated().forEach { result[$0.offset] = $0.element }
		return result
	}
}

extension Sequence {

	func group(_ comp: (Self.Iterator.Element, Self.Iterator.Element) -> Bool) -> [[Self.Iterator.Element]] {

		var result: [[Self.Iterator.Element]] = []
		var current: [Self.Iterator.Element] = []

		for element in self {
			if current.isEmpty || comp(element, current.last!) {
				current.append(element)
			} else {
				result.append(current)
				current = [element]
			}
		}

		if !current.isEmpty {
			result.append(current)
		}

		return result
	}
}

extension MutableCollection where Indices.Iterator.Element == Index {
	/// Shuffles the contents of this collection.
	mutating func shuffle() {
		let c = count
		guard c > 1 else { return }

		for (firstUnshuffled , unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
			let d: IndexDistance = random[0...numericCast(unshuffledCount-1)]|>numericCast
			guard d != 0 else { continue }
			let i = index(firstUnshuffled, offsetBy: d)
			swap(&self[firstUnshuffled], &self[i])
		}
	}
}

extension Sequence {
	/// Returns an array with the contents of this sequence, shuffled.
	func shuffled() -> [Iterator.Element] {
		var result = Array(self)
		result.shuffle()
		return result
	}
}


// Local Tests
if let inputFile = Bundle.main.path(forResource: "input", ofType: "txt") {
	freopen(inputFile, "r", stdin)
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// MARK: - ここテン
////////////////////////////////////////////////////////////////////////////////

let MAP_WIDTH = 23
let MAP_HEIGHT = 21
let COOLDOWN_CANNON = 2
let COOLDOWN_MINE = 5
let INITIAL_SHIP_HEALTH = 100
let MAX_SHIP_HEALTH = 100
//let MAX_SHIP_SPEED
let MIN_SHIPS = 1
//let MAX_SHIPS
//let MIN_MINES
//let MAX_MINES
let MIN_RUM_BARRELS = 10
let MAX_RUM_BARRELS = 26
let MIN_RUM_BARREL_VALUE = 10
let MAX_RUM_BARREL_VALUE = 20
let REWARD_RUM_BARREL_VALUE = 30
let MINE_VISIBILITY_RANGE = 5
let FIRE_DISTANCE_MAX = 10
let LOW_DAMAGE = 25
let HIGH_DAMAGE = 50
let MINE_DAMAGE = 25
let NEAR_MINE_DAMAGE = 10



func isInsideMap(_ point: Hex2d) -> Bool {
	return point.x >= 0 && point.x < MAP_WIDTH && point.y >= 0 && point.y < MAP_HEIGHT
}


// game loop
var fireCooldown = 3
for turn in 0..<200 {
	let myShipCount = Int(readLine()!)! // the number of remaining ships
	let entityCount = Int(readLine()!)! // the number of entities (e.g. ships, mines or cannonballs)
	var myship: Int2d!
	var yourship: Int2d!
	var yourshipRotation: Int = 0
	var yourshipSpeed: Int = 0
	var barrel: (at: Int2d, rum: Int) = (at: (x:0, y:0), rum: 0)
	if entityCount > 0 {
		for i in 0...(entityCount-1) {
			let inputs = (readLine()!).characters.split{$0 == " "}.map(String.init)
			let entityId = Int(inputs[0])!
			let entityType = inputs[1]
			let x = Int(inputs[2])!
			let y = Int(inputs[3])!
			let arg1 = Int(inputs[4])!
			let arg2 = Int(inputs[5])!
			let arg3 = Int(inputs[6])!
			let arg4 = Int(inputs[7])!

			switch( entityType ) {
			case "SHIP":
				if( arg4 ==  1) { // mine
					myship = (x: x, y: y)
				}
				else {
					yourship = (x: x, y: y)
					yourshipRotation = arg1
					yourshipSpeed = arg2
				}
				break;
			case "BARREL":
				if( arg1 > barrel.rum ) {
					barrel = (at: (x: x, y: y), rum: arg1)
				}
				break;
			default: break;
			}
		}
	}
	guard myShipCount > 0 else { continue }

	fireCooldown = max(fireCooldown - 1, 0)
	for i in 0..<myShipCount {

		if fireCooldown == 0 {
			let target = Hex2d(yourship)
			let course = Hex2d.direction(index: yourshipRotation)
			let currentRange = 2 // Hex2d(myship).distance(to: target)
			let advancedTarget = target + (course * currentRange * yourshipSpeed)

			log("target: \(target)")
			log("course: \(course)")
			log("currentRange: \(currentRange)")
			log("advancedTarget: \(advancedTarget)")
			log("fireto: \(advancedTarget.int2d)")

			if Hex2d(myship).distance(to: advancedTarget) <= FIRE_DISTANCE_MAX {
				print("FIRE \(advancedTarget.int2d.x) \(advancedTarget.int2d.y)")
				fireCooldown = 2
				continue
			}
		}

		print("MOVE \(barrel.at.x) \(barrel.at.y)")
	}
}
