#!/usr/bin/env swift

import Foundation
import CoreLocation
import MapKit

struct GeoBox {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    
    var centerLat: Double { (minLat + maxLat) / 2 }
    var centerLon: Double { (minLon + maxLon) / 2 }
}

struct ElevationData {
    let elevation: Double
    let rainfall: Int
    let tempLow: Int
    let tempHigh: Int
    
    func toCSV() -> String {
        return "\(elevation),\(rainfall),\(tempLow),\(tempHigh)"
    }
}

class GeoGridGenerator {
    let rows: Int
    let cols: Int
    let geoBox: GeoBox
    let radius: Double
    let outputPath: String
    
    init(rows: Int, cols: Int, geoBox: GeoBox, radius: Double = 25.0, outputPath: String = "geo_grid.txt") {
        self.rows = rows
        self.cols = cols
        self.geoBox = geoBox
        self.radius = radius
        self.outputPath = outputPath
    }
    
    func generateGrid() async -> String {
        var gridData: [ElevationData] = []
        
        let latStep = (geoBox.maxLat - geoBox.minLat) / Double(rows - 1)
        let lonStep = (geoBox.maxLon - geoBox.minLon) / Double(cols - 1)
        
        print("Generating \(rows)x\(cols) grid...")
        print("Lat range: \(geoBox.minLat) to \(geoBox.maxLat)")
        print("Lon range: \(geoBox.minLon) to \(geoBox.maxLon)")
        print("Step size: lat=\(latStep), lon=\(lonStep)")
        
        for row in 0..<rows {
            for col in 0..<cols {
                let lat = geoBox.minLat + Double(row) * latStep
                let lon = geoBox.minLon + Double(col) * lonStep
                
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let elevation = await fetchElevation(for: coordinate)
                
                // Generate some sample climate data
                // You can customize this based on your needs
                let rainfall = Int.random(in: 1...5)
                let tempLow = Int.random(in: 20...50)
                let tempHigh = tempLow + Int.random(in: 10...30)
                
                gridData.append(ElevationData(
                    elevation: elevation,
                    rainfall: rainfall,
                    tempLow: tempLow,
                    tempHigh: tempHigh
                ))
            }
            
            // Progress indicator
            if (row + 1) % 5 == 0 || row == rows - 1 {
                print("Processed \(row + 1)/\(rows) rows...")
            }
        }
        
        return encodeGrid(data: gridData)
    }
    
    func fetchElevation(for coordinate: CLLocationCoordinate2D) async -> Double {
        // Use MKMapSnapshotter to get elevation data
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        )
        options.size = CGSize(width: 100, height: 100)
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            
            // Try to get elevation using CLLocation
            // Note: Real elevation requires additional APIs or data sources
            // This is a placeholder that returns sea level (0) by default
            // You could integrate with a third-party elevation API here
            
            return 0.0 // Default elevation at sea level
        } catch {
            print("Warning: Failed to fetch data for \(coordinate.latitude), \(coordinate.longitude)")
            return 0.0
        }
    }
    
    func encodeGrid(data: [ElevationData]) -> String {
        var result = ""
        result += "radius:\(radius)\n"
        result += "size:\(rows)^\(cols)\n"
        result += "path:\(outputPath)\n"
        result += "+data:\n"
        
        // Write rows from north to south (highest lat to lowest lat)
        // This means the top row in the file represents the northern part of the map
        for row in (0..<rows).reversed() {
            var line: [String] = []
            for col in 0..<cols {
                let index = row * cols + col
                line.append(data[index].toCSV())
            }
            result += line.joined(separator: "\t") + "\n"
        }
        
        result += "-data:\n"
        return result
    }
}

// Command line argument parsing
func printUsage() {
    print("""
    Usage: generate_geo_grid.swift [options]
    
    Options:
      --rows N          Number of rows (default: 10)
      --cols N          Number of columns (default: 10)
      --min-lat LAT     Minimum latitude (default: 37.0)
      --max-lat LAT     Maximum latitude (default: 38.0)
      --min-lon LON     Minimum longitude (default: -122.5)
      --max-lon LON     Maximum longitude (default: -121.5)
      --radius R        Hex radius (default: 25.0)
      --output PATH     Output file path (default: geo_grid.txt)
      --help            Show this help message
    
    Example:
      swift generate_geo_grid.swift --rows 20 --cols 20 --min-lat 37.7 --max-lat 37.8 --min-lon -122.5 --max-lon -122.4
    """)
}

// Parse command line arguments
var rows = 10
var cols = 10
var minLat = 37.0
var maxLat = 38.0
var minLon = -122.5
var maxLon = -121.5
var radius = 25.0
var outputPath = "geo_grid.txt"

var args = CommandLine.arguments
var i = 1

while i < args.count {
    let arg = args[i]
    
    switch arg {
    case "--help", "-h":
        printUsage()
        exit(0)
    case "--rows":
        i += 1
        if i < args.count, let value = Int(args[i]) {
            rows = value
        }
    case "--cols":
        i += 1
        if i < args.count, let value = Int(args[i]) {
            cols = value
        }
    case "--min-lat":
        i += 1
        if i < args.count, let value = Double(args[i]) {
            minLat = value
        }
    case "--max-lat":
        i += 1
        if i < args.count, let value = Double(args[i]) {
            maxLat = value
        }
    case "--min-lon":
        i += 1
        if i < args.count, let value = Double(args[i]) {
            minLon = value
        }
    case "--max-lon":
        i += 1
        if i < args.count, let value = Double(args[i]) {
            maxLon = value
        }
    case "--radius":
        i += 1
        if i < args.count, let value = Double(args[i]) {
            radius = value
        }
    case "--output":
        i += 1
        if i < args.count {
            outputPath = args[i]
        }
    default:
        print("Unknown argument: \(arg)")
        printUsage()
        exit(1)
    }
    
    i += 1
}

// Validate inputs
guard rows > 0 && cols > 0 else {
    print("Error: Rows and columns must be positive")
    exit(1)
}

guard minLat < maxLat && minLon < maxLon else {
    print("Error: Min coordinates must be less than max coordinates")
    exit(1)
}

// Generate the grid
let geoBox = GeoBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
let generator = GeoGridGenerator(rows: rows, cols: cols, geoBox: geoBox, radius: radius, outputPath: outputPath)

Task {
    let encoded = await generator.generateGrid()
    
    // Write to file
    do {
        try encoded.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("\n✓ Grid generated successfully!")
        print("Output written to: \(outputPath)")
        print("Grid size: \(rows)x\(cols) = \(rows * cols) cells")
    } catch {
        print("Error writing to file: \(error)")
        exit(1)
    }
    
    exit(0)
}

// Keep the script running for async operations
RunLoop.main.run()
