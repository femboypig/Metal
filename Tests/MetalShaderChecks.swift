import Foundation
import Metal

@main
enum MetalShaderChecks {
    static func main() throws {
        let source = try String(contentsOfFile: "Metal/ViewController+UI.swift", encoding: .utf8)
        let marker = "private let waveMetalShaderSource = \"\"\""
        guard let start = source.range(of: marker),
              let end = source.range(of: "\"\"\"", range: start.upperBound..<source.endIndex) else {
            fatalError("Embedded Metal shader source is missing")
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Hosted macOS VMs can lack a GPU; the iOS build still runs below.
            print("Metal shader runtime validation unavailable: runner has no Metal device")
            return
        }
        let library = try device.makeLibrary(source: String(source[start.upperBound..<end.lowerBound]), options: nil)
        for name in ["waveFragmentShader", "mixBurstFragmentShader"] {
            let pipeline = MTLRenderPipelineDescriptor()
            pipeline.vertexFunction = library.makeFunction(name: "waveVertexShader")
            pipeline.fragmentFunction = library.makeFunction(name: name)
            precondition(pipeline.vertexFunction != nil && pipeline.fragmentFunction != nil)
            pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline.colorAttachments[0].isBlendingEnabled = true
            pipeline.colorAttachments[0].sourceRGBBlendFactor = .one
            pipeline.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipeline.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipeline.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            _ = try device.makeRenderPipelineState(descriptor: pipeline)
        }
        print("Wave and remix Metal shader pipelines compiled successfully")
    }
}
