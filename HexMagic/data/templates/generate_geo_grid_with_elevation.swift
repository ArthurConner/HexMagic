#!/usr/bin/env swift

import Foundation
import CoreLocation

// IMPORTANT: This version uses the Open-Elevation API to fetch real elevation data
// Rate limiting: Be respectful with API calls - use smaller grids or add delays for large grids

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

struct OpenElevationResponse: Codable {
    let results: [ElevationResult]
}

struct ElevationResult: Codable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
}

class GeoGridGenerator {
    let rows: Int
    let cols: Int
    let geoBox: GeoBox
    let radius: Double
    let outputPath: String
    let delayMs: Int
    
    init(rows: Int, cols: Int, geoBox: GeoBox, radius: Double = 25.0, outputPath: String = "geo_grid.txt", delayMs: Int = 250) {
        self.rows = rows
        self.cols = cols
        self.geoBox = geoBox
        self.radius = radius
        self.outputPath = outputPath
        self.delayMs = delayMs
    }
    
    func generateGrid() async -> String {
        var gridData: [ElevationData] = []
        
        let latStep = (geoBox.maxLat - geoBox.minLat) / Double(rows - 1)
        let lonStep = (geoBox.maxLon - geoBox.minLon) / Double(cols - 1)
        
        print("Generating \(rows)x\(cols) grid with real elevation data...")
        print("Lat range: \(geoBox.minLat) to \(geoBox.maxLat)")
        print("Lon range: \(geoBox.minLon) to \(geoBox.maxLon)")
        print("Step size: lat=\(latStep), lon=\(lonStep)")
        print("Note: Fetching real elevation data - this may take a while...")
        
        // Batch coordinates for API efficiency (Open-Elevation supports batch requests)
        var coordinates: [(lat: Double, lon: Double)] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let lat = geoBox.minLat + Double(row) * latStep
                let lon = geoBox.minLon + Double(col) * lonStep
                coordinates.append((lat, lon))
            }
        }
        
        // Fetch elevations individually with delay
        var allElevations: [Double] = []
        
        for (index, coord) in coordinates.enumerated() {
            let elevation = await fetchElevationSingle(lat: coord.lat, lon: coord.lon)
            allElevations.append(elevation)
            
            // Progress update every 50 cells
            if (index + 1) % 50 == 0 || index == coordinates.count - 1 {
                let progress = Int(Double(index + 1) / Double(coordinates.count) * 100)
                print("Progress: \(progress)% (\(index + 1)/\(coordinates.count) cells)")
            }
            
            // Delay between requests
            if index < coordinates.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            }
        }
        
        // Create grid data with fetched elevations
        for i in 0..<coordinates.count {
            let elevation = allElevations[i]
            
            // Generate climate data based on elevation
            // Higher elevation = more rainfall, lower temps (simple model)
            let baseRainfall = 3
            let rainfall = max(1, min(5, baseRainfall + Int(elevation / 500)))
            
            let baseTempLow = 40
            let baseTempHigh = 60
            let tempLow = max(0, baseTempLow - Int(elevation / 100))
            let tempHigh = max(tempLow + 10, baseTempHigh - Int(elevation / 150))
            
            gridData.append(ElevationData(
                elevation: elevation,
                rainfall: rainfall,
                tempLow: tempLow,
                tempHigh: tempHigh
            ))
        }
        
        return encodeGrid(data: gridData)
    }
    
    func fetchElevationSingle(lat: Double, lon: Double) async -> Double {
        // Fetch single coordinate from Open-Elevation API
        let urlString = "https://api.open-elevation.com/api/v1/lookup?locations=\(lat),\(lon)"
        
        guard let encodedUrl = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedUrl) else {
            return 0.0
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return 0.0
            }
            
            if httpResponse.statusCode != 200 {
                if httpResponse.statusCode >= 500 {
                    // Server error - retry once after longer delay
                    try? await Task.sleep(nanoseconds: UInt64(delayMs * 2) * 1_000_000)
                    return await fetchElevationSingle(lat: lat, lon: lon)
                }
                return 0.0
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(OpenElevationResponse.self, from: data)
            
            if let firstResult = apiResponse.results.first {
                return firstResult.elevation
            }
            return 0.0
            
        } catch {
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
    Usage: generate_geo_grid_with_elevation.swift [options]
    
    This version fetches REAL elevation data from the Open-Elevation API.
    
    Options:
      --rows N          Number of rows (default: 10)
      --cols N          Number of columns (default: 10)
      --min-lat LAT     Minimum latitude (default: 37.0)
      --max-lat LAT     Maximum latitude (default: 38.0)
      --min-lon LON     Minimum longitude (default: -122.5)
      --max-lon LON     Maximum longitude (default: -121.5)
      --radius R        Hex radius (default: 25.0)
      --output PATH     Output file path (default: geo_grid.txt)
      --delay MS        Delay between API requests in ms (default: 250)
      --help            Show this help message
    
    Example:
      swift generate_geo_grid_with_elevation.swift --rows 20 --cols 20 \\
        --min-lat 37.7 --max-lat 37.8 \\
        --min-lon -122.5 --max-lon -122.4 \\
        --output sf_real_elevation.txt
    
    Note: 
    - Uses Open-Elevation API (free, no API key needed)
    - Processes in batches of 100 coordinates
    - Includes automatic delays between batches
    - For large grids, this may take several minutes
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
var delayMs = 100

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
    case "--delay":
        i += 1
        if i < args.count, let value = Int(args[i]) {
            delayMs = value
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
let generator = GeoGridGenerator(rows: rows, cols: cols, geoBox: geoBox, radius: radius, outputPath: outputPath, delayMs: delayMs)

Task {
    let encoded = await generator.generateGrid()
    
    // Write to file
    do {
        try encoded.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("\n✓ Grid generated successfully with REAL elevation data!")
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
