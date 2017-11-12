//
//  BezierBuildingTests.swift
//  TheAmazingPlotterTests
//
//  Created by Massimo Cesaraccio on 12/11/2017.
//  Copyright © 2017 Massimo Cesaraccio. All rights reserved.
//

import XCTest
@testable import TheAmazingPlotter

class BezierBuildingTests: XCTestCase {
    func test_addPointShouldChangeData() {
        var bezier = Bezier(withPoint: CGPoint.zero)
        XCTAssertNoThrow(try bezier.add(CGPoint(x: 1, y: 1)))
        XCTAssertTrue(bezier.isOpen)
        XCTAssertEqual(bezier.points, [CGPoint.zero, CGPoint(x: 1, y: 1)])
    }
    
    func test_buildPathWithLessThanThreePointsShouldThrow() {
        var bezier = Bezier(withPoint: CGPoint.zero)
        try! bezier.add(CGPoint(x: 1, y: 1))
        XCTAssertThrowsError(try bezier.buildPath())
    }
    
    func test_buildPathWithThreePointsShouldThrow() {
        var bezier = Bezier(withPoint: CGPoint.zero)
        try! bezier.add(CGPoint(x: 1, y: 1))
        try! bezier.add(CGPoint(x: 2, y: 2))
        XCTAssertNoThrow(try bezier.buildPath())
    }
    
    func test_buildPathShouldContainAllPoints() {
        let points = [CGPoint.zero, CGPoint(x: 1, y: 1), CGPoint(x: 3, y: 4), CGPoint(x: 10, y: 2)]
        var bezier = Bezier(withPoint: points[0])
        for i in 1..<points.count {
            try! bezier.add(points[i])
        }
        guard let bezierPath = try? bezier.buildPath() else {
            XCTFail("unexpected failure creating path")
            return
        }
        let containsAll = points[0..<points.count - 1].reduce(true) { (contains, p) in
            return contains && bezierPath.contains(p)
        }
        XCTAssertTrue(containsAll)
        XCTAssertEqual(bezier.segments.count, 2)
    }
    
    func test_pathFromClosedBezierShouldContainAllPoints() {
        let points = [CGPoint.zero, CGPoint(x: 1, y: 1), CGPoint(x: 3, y: 4), CGPoint(x: 10, y: 2)]
        var bezier = Bezier(withPoint: points[0])
        for i in 1..<points.count {
            try! bezier.add(points[i])
        }
        XCTAssertNoThrow(try bezier.close())
        guard let bezierPath = try? bezier.buildPath() else {
            XCTFail("unexpected failure creating path")
            return
        }
        let containsAll = points[0..<points.count].reduce(true) { (contains, p) in
            return contains && bezierPath.contains(p)
        }
        XCTAssertTrue(containsAll)
        XCTAssertEqual(bezier.segments.count, 3)
    }
    
    func test_closingMoreThanOnceShouldThrow() {
        let points = [CGPoint.zero, CGPoint(x: 1, y: 1), CGPoint(x: 3, y: 4), CGPoint(x: 10, y: 2)]
        var bezier = Bezier(withPoint: points[0])
        for i in 1..<points.count {
            try! bezier.add(points[i])
        }
        XCTAssertNoThrow(try bezier.close())
        XCTAssertThrowsError(try bezier.close())
    }
    
    func test_addingToAClosedBezierShouldThrow() {
        var bezier = Bezier(withPoint: CGPoint.zero)
        try! bezier.close()
        XCTAssertThrowsError(try bezier.add(CGPoint(x: 1, y: 1)))
    }
}
