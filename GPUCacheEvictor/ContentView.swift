import SwiftUI

struct ContentView: View {
    @State private var renderer: Renderer?
    @State private var errorMessage: String?
    
    // --- ADDITION: State to hold the user's kernel choice ---
    @State private var selectedKernel: KernelType = .linear
    
    @State private var results: String = "Select a kernel and press 'Run Test'."
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 20) {
            Text("GPU Cache Eviction Experiment")
                .font(.title)

            if let errorMessage = errorMessage {
                Text("Error initializing Renderer:\n\n\(errorMessage)")
                    .foregroundColor(.red).padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(results)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .border(Color.gray, width: 1)
            }
            
            HStack {
                // --- ADDITION: A picker to select the kernel ---
                Picker("Kernel:", selection: $selectedKernel) {
                    ForEach(KernelType.allCases) { kernel in
                        Text(kernel.rawValue).tag(kernel)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(isRunning)

                Spacer()
                
                Button(action: { runTest() }) {
                    if isRunning {
                        ProgressView().padding(.horizontal); Text("Testing...")
                    } else {
                        Text("Run Test")
                    }
                }
                .disabled(isRunning || renderer == nil)
            }
            .padding([.horizontal, .bottom])
        }
        .padding()
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            do {
                renderer = try Renderer()
            } catch {
                self.errorMessage = error.localizedDescription
                print("Renderer failed to initialize: \(error)")
            }
        }
    }

    private func runTest() {
        guard let renderer = renderer else {
            results = "Error: Renderer is not available."
            return
        }
        
        isRunning = true
        results = "Starting test...\n\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            // --- CHANGE: Pass the selected kernel to the function ---
            let testResults = renderer.runExperiment(kernelToUse: selectedKernel)
            
            DispatchQueue.main.async {
                results = testResults
                isRunning = false
            }
        }
    }
}
