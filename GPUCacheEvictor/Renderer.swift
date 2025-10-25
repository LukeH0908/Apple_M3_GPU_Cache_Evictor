import Foundation
import Metal
import simd

enum RendererError: Error {
    case metalNotSupported, deviceInitializationFailed, commandQueueCreationFailed, libraryCreationFailed, kernelFunctionNotFound(String), pipelineStateCreationFailed(Error)
}

// --- ADDITION: An enum to represent your two kernels ---
enum KernelType: String, CaseIterable, Identifiable {
    case linear = "Linear Pump"
    case random = "Random Pump"
    var id: String { self.rawValue }
}

class Renderer: ObservableObject {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let threadgroupSize = 128

    // --- CHANGE 1: Store two separate pipeline states ---
    let linearScanPipeline: MTLComputePipelineState
    let randomScanPipeline: MTLComputePipelineState

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw RendererError.metalNotSupported }
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else { throw RendererError.commandQueueCreationFailed }
        self.commandQueue = commandQueue
        guard let library = device.makeDefaultLibrary() else { throw RendererError.libraryCreationFailed }

        // --- CHANGE 2: Create a pipeline for the LINEAR kernel ---
        // Make sure your Metal function name matches "in_shader_pump_probe_linear"
        let linearKernelName = "in_shader_pump_probe_linear"
        guard let linearFunction = library.makeFunction(name: linearKernelName) else { throw RendererError.kernelFunctionNotFound(linearKernelName) }
        self.linearScanPipeline = try device.makeComputePipelineState(function: linearFunction)
        
        // --- CHANGE 3: Create a pipeline for the RANDOM kernel ---
        // Make sure your Metal function name matches "in_shader_pump_probe_random"
        let randomKernelName = "in_shader_pump_probe_random"
        guard let randomFunction = library.makeFunction(name: randomKernelName) else { throw RendererError.kernelFunctionNotFound(randomKernelName) }
        self.randomScanPipeline = try device.makeComputePipelineState(function: randomFunction)
    }

    // --- CHANGE 4: The function now takes an argument to select the kernel ---
    func runExperiment(kernelToUse: KernelType) -> String {
        let testSizesInKB = Array(stride(from:1, through: 4*1024, by: 1))
        
        var resultsLog = ""
        resultsLog += "Testing Range: \(testSizesInKB[0]) KB - \(testSizesInKB[testSizesInKB.count-1]) KB (Step: 1 KB) using \(kernelToUse.rawValue)\n\n"
        resultsLog += "Eviction Buffer Size (KB) | Total Time |  Latency (Δ)\n"
        resultsLog += "--------------------------------------------------\n"
        
        let probeBuffer = device.makeBuffer(length: 64, options: .storageModeShared)!
        let resultBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * 4, options: .storageModeShared)!

        for sizeKB in testSizesInKB {
            let pumpElementCount = (sizeKB * 1024) / MemoryLayout<UInt32>.stride
            guard pumpElementCount > 0 else { continue }
            
            let pumpBuffer = device.makeBuffer(length: pumpElementCount * MemoryLayout<UInt32>.stride, options: .storageModeShared)!
            
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            // --- CHANGE 5: Set the pipeline state based on the selection ---
            switch kernelToUse {
            case .linear:
                commandEncoder.setComputePipelineState(linearScanPipeline)
            case .random:
                commandEncoder.setComputePipelineState(randomScanPipeline)
            }
            
            commandEncoder.setBuffer(probeBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(pumpBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(resultBuffer, offset: 0, index: 2)
            var mutableElementCount = pumpElementCount
            commandEncoder.setBytes(&mutableElementCount, length: MemoryLayout<Int>.stride, index: 3)
            
            commandEncoder.setThreadgroupMemoryLength(16, index: 0)
            commandEncoder.setThreadgroupMemoryLength(16, index: 1)

            let threads = MTLSize(width: self.threadgroupSize, height: 1, depth: 1)
            let groups = MTLSize(width: 1, height: 1, depth: 1)
            commandEncoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
            
            commandEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            let resultsPtr = resultBuffer.contents().bindMemory(to: UInt32.self, capacity: 4)
            let counterResult = resultsPtr[0]
            _ = resultsPtr[1]
            let pumpSumResult = resultsPtr[2]
            _ = resultsPtr[3]

            let logLine = String(format: "%-16d | %-14u | %u\n", sizeKB, counterResult, pumpSumResult)
            print(logLine, terminator: "")
            resultsLog += logLine
        }
        return resultsLog
    }
}
