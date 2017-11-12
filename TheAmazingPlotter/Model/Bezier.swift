//
//  Bezier.swift
//  TheAmazingPlotter
//
//  Created by Massimo Cesaraccio on 12/11/2017.
//  Copyright © 2017 Massimo Cesaraccio. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

enum BezierError: Error {
    case notEnoughPointsToComputePath
    case addingToClosedBezier
    case closingAnAlreadyClosedBezier
}

struct CubicCurveSegment {
    var controlPoint1: CGPoint
    var controlPoint2: CGPoint
}

/// Represents a cubic bezier.
struct Bezier {
    /// _true_ if the bezier is open.
    private (set) var isOpen = true
    /// The points added to the bezier.
    private (set) var points: [CGPoint]
    /// The curve segments computed until now.
    private (set) var segments: [CubicCurveSegment] = []
    
    /// Initializes the bezier from a starting point.
    init(withPoint start: CGPoint) {
        points = [start]
    }
    
    /// Adds a point and tries to build new segments.
    ///
    /// - Parameter point: The point to be added.
    /// - Returns: _true_ is new segments were built.
    /// - Throws: `BezierError.addingToClosedBezier` if the bezier has been closed.
    @discardableResult mutating func add(_ point: CGPoint) throws -> Bool {
        guard isOpen else {
            throw BezierError.addingToClosedBezier
        }
        points.append(point)
        return buildSegments()
    }
    
    /// Attempts to close the bezier and build new segments.
    ///
    /// - Returns: _true_ is new segments were built.
    /// - Throws: `BezierError.addingToClosedBezier` if the bezier has already been closed.
    @discardableResult mutating func close() throws -> Bool {
        guard isOpen else {
            throw BezierError.closingAnAlreadyClosedBezier
        }
        isOpen = false
        return buildSegments()
    }
    
    /// Attempts to build a `UIBezierPath`.
    ///
    /// - Returns: A newly build `UIBezierPath`.
    /// - Throws: `BezierError.notEnoughPointsToComputePath` if the bezier hasn't got enough points to compute a path.
    @discardableResult func buildPath() throws -> UIBezierPath {
        guard points.count > 2, segments.count > 0, points.count > segments.count else {
            throw BezierError.notEnoughPointsToComputePath
        }
        let path = UIBezierPath()
        path.move(to: points[0])
        for i in 0 ..< segments.count {
            let segment = segments[i]
            let point = points[i + 1]
            path.addCurve(to: point, controlPoint1: segment.controlPoint1, controlPoint2: segment.controlPoint2)
        }
        return path
    }
}

// MARK: - Building of segments and paths.

extension Bezier {
    /// Attempts to build new segments.
    ///
    /// - Returns: _true_ is new segments were built.
    fileprivate mutating func buildSegments() -> Bool {
        // we can add segment i (i.e. starting from the i-th point, when we have the (i+2)-th or (i+1)-th point,
        // depending on whether the bezier is open or not
        let maxSegments = points.count - (isOpen ? 2 : 1)
        guard points.count > 2, segments.count < maxSegments else {
            return false
        }
        // extract the subarray of points that includes the start of the last segment we have (if any) and use it
        // to build new segments, of which we'll discard the one overlapping with the existing ones.
        let pointsForNewSegmentsStart = segments.isEmpty ? 0 : segments.count - 1 
        let pointsForNewSegments = points[pointsForNewSegmentsStart ..< points.count]
        let newSegments = Bezier.segmentsFromPoints(dataPoints: Array(pointsForNewSegments))
        guard !newSegments.isEmpty else {
            return false
        }
        // if we haven't added any segments yet we take the forst too, otherwise we skip it. 
        let firstSegmentIdx = segments.isEmpty ? 0 : 1 
        // If the bezier is still open we skip the last one. 
        let lastSegmentIdx = newSegments.count - (isOpen ? 2 : 1) 
        segments.append(contentsOf: newSegments[firstSegmentIdx ... lastSegmentIdx])
        return true
    }
    
    /// Builds new segments from the provided array of points.
    ///
    /// - Parameter dataPoints: the points for which curve segments will be computed.
    /// - Returns: the array of curve segments connecting the points.
    static private func segmentsFromPoints(dataPoints: [CGPoint]) -> [CubicCurveSegment] {
        let segmentsCount = dataPoints.count - 1
        // P0, P1, P2, P3 are the points for each segment, where P0 & P3 are the knots and P1, P2 are the control points.
        guard segmentsCount > 1 else {
            return []
        } 
        
        // We'll solve Ax=B, rhs stands for B, the rhs of the equation
        var rhsArray = [CGPoint]()
        
        // Array of Lhs Coefficients for P(1, i-1), P(1, i) and P(1, i + 1) 
        var a = [CGFloat]()
        var b = [CGFloat]()
        var c = [CGFloat]()
        
        // For rhs values we need two adjacent segments i and i+1
        for i in 0..<segmentsCount {
            let P0 = dataPoints[i]
            let P3 = dataPoints[i + 1]
            let rhsValue: CGPoint
            switch i {
            case 0:
                a.append(0)
                b.append(2)
                c.append(1)
                // rhs for first segment
                rhsValue = CGPoint(x: P0.x + 2 * P3.x, 
                                   y: P0.y + 2 * P3.y)
            case segmentsCount - 1:
                a.append(2)
                b.append(7)
                c.append(0)
                // rhs for last segment
                rhsValue = CGPoint(x: 8 * P0.x + P3.x, 
                                   y: 8 * P0.y + P3.y)
            default:
                a.append(1)
                b.append(4)
                c.append(1)
                // rhs for any middle segment
                rhsValue = CGPoint(x: 4 * P0.x + 2 * P3.x, 
                                   y: 4 * P0.y + 2 * P3.y)
            }
            rhsArray.append(rhsValue)
        }
        
        // Solve Ax=B. Use Tridiagonal matrix algorithm a.k.a Thomas Algorithm
        for i in 1..<segmentsCount {
            let rhsValue = rhsArray[i]
            let prevRhsValue = rhsArray[i - 1]
            
            let m = a[i] / b[i - 1]
            let b1 = b[i] - m * c[i - 1]
            b[i] = b1
            
            let r2x = rhsValue.x - m * prevRhsValue.x
            let r2y = rhsValue.y - m * prevRhsValue.y
            rhsArray[i] = CGPoint(x: r2x, y: r2y)
        }
        
        // Get First Control Points
        var firstControlPoints = Array<CGPoint>(repeating: .zero, count: segmentsCount)
        // Last control Point
        let lastControlPointX = rhsArray[segmentsCount - 1].x / b[segmentsCount - 1]
        let lastControlPointY = rhsArray[segmentsCount - 1].y / b[segmentsCount - 1]
        firstControlPoints[segmentsCount - 1] = CGPoint(x: lastControlPointX, y: lastControlPointY)
        
        for i in (0..<segmentsCount - 1).reversed() {
            let nextControlPoint = firstControlPoints[i + 1]
            let controlPointX = (rhsArray[i].x - c[i] * nextControlPoint.x) / b[i]
            let controlPointY = (rhsArray[i].y - c[i] * nextControlPoint.y) / b[i]
            firstControlPoints[i] = CGPoint(x: controlPointX, y: controlPointY)
        }
        
        // Compute second Control Points from first
        var secondControlPoints = Array<CGPoint>(repeating: .zero, count: firstControlPoints.count)
        for i in 0..<segmentsCount {
            let controlPoint: CGPoint
            switch i {
            case segmentsCount - 1:
                let P3 = dataPoints[i + 1]
                let P1 = firstControlPoints[i]
                controlPoint = CGPoint(x: (P3.x + P1.x) / 2, y: (P3.y + P1.y) / 2)
            default:
                let P3 = dataPoints[i + 1]
                let nextP1 = firstControlPoints[i + 1]
                controlPoint = CGPoint(x: 2 * P3.x - nextP1.x, y: 2 * P3.y - nextP1.y)
            }
            secondControlPoints[i] = controlPoint
        }
        
        var controlPoints = [CubicCurveSegment]()
        for i in 0..<segmentsCount {
            let firstControlPoint = firstControlPoints[i]
            let secondControlPoint = secondControlPoints[i]
            let segment = CubicCurveSegment(controlPoint1: firstControlPoint, controlPoint2: secondControlPoint)
            controlPoints.append(segment)
        }
        return controlPoints
    }
}
