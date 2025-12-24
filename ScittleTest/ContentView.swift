//
//  ContentView.swift
//  ClojureScriptTest
//
//  Created by Rod Schmidt on 12/15/25.
//

import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ClojureViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section("REPL") {
                    TextEditor(text: $viewModel.replInput)
                        .frame(height: 100)
                        .font(.system(.body, design: .monospaced))
                        .border(Color.gray.opacity(0.3))
                    
                    Button("Evaluate") {
                        viewModel.evaluateREPL()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if !viewModel.replOutput.isEmpty {
                        Text(viewModel.replOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                            .textSelection(.enabled)
                    }
                }
                
                Section("Quick Tests") {
                    Button("Greet 'iOS'") {
                        viewModel.testGreet()
                    }
                    
                    Button("Calculate 5 × 3") {
                        viewModel.testCalculate()
                    }
                    
                    Button("Increment Counter") {
                        viewModel.testCounter()
                    }
                    
                    Button("Square of 7") {
                        viewModel.testSquare()
                    }
                    
                    Button("Factorial of 5") {
                        viewModel.testFactorial()
                    }
                    
                    Button("Filter Evens [1..10]") {
                        viewModel.testFilterEvens()
                    }
                }
                
                Section("Swift Interop - Call Swift from Clojure") {
                    Button("Get Current Time") {
                        viewModel.testGetCurrentTime()
                    }
                    
                    Button("Show Alert") {
                        viewModel.testShowAlert()
                    }
                    
                    Button("Save Preference") {
                        viewModel.testSavePreference()
                    }
                    
                    Button("Complex Interop") {
                        viewModel.testComplexInterop()
                    }
                }
                
                Section("Result") {
                    Text(viewModel.result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                Section("Alert Log") {
                    if viewModel.alertLog.isEmpty {
                        Text("No alerts yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.alertLog, id: \.self) { alert in
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                                Text(alert)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Load New Code") {
                    TextEditor(text: $viewModel.newCode)
                        .frame(height: 150)
                        .font(.system(.caption, design: .monospaced))
                        .border(Color.gray.opacity(0.3))
                    
                    Button("Load & Test") {
                        viewModel.loadAndTestNewCode()
                    }
                }
            }
            .navigationTitle("Scittle REPL")
        }
    }
}

class ClojureViewModel: ObservableObject {
    private var clojure: ClojureAPI?
    
    @Published var replInput = "(+ 1 2 3)"
    @Published var replOutput = ""
    @Published var result = "Ready! Try the examples below."
    @Published var alertLog: [String] = []
    @Published var newCode = """
    (defn my-function [x]
      (* x x x))
    """
    
    init() {
        do {
            self.clojure = try ClojureAPI()
            // Set up callback for alerts
            self.clojure?.setAlertCallback { [weak self] message in
                DispatchQueue.main.async {
                    self?.alertLog.append(message)
                }
            }
            result = "✅ Clojure initialized!"
        } catch {
            print("Failed to initialize Clojure: \(error)")
            result = "❌ Initialization failed: \(error)"
        }
    }
    
    func evaluateREPL() {
        guard let clojure = clojure else { return }
        do {
            let output = try clojure.eval(replInput)
            replOutput = "=> \(String(describing: output ?? "nil"))"
            result = replOutput
        } catch {
            replOutput = "Error: \(error)"
            result = replOutput
        }
    }
    
    func testGreet() {
        guard let clojure = clojure else { return }
        do {
            let greeting = try clojure.greet(name: "iOS")
            result = "✅ \(greeting)"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testCalculate() {
        guard let clojure = clojure else { return }
        do {
            let answer = try clojure.calculate(operation: "multiply", x: 5, y: 3)
            result = "✅ 5 × 3 = \(answer)"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testCounter() {
        guard let clojure = clojure else { return }
        do {
            let count = try clojure.incrementCounter()
            result = "✅ Counter: \(count)"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testSquare() {
        guard let clojure = clojure else { return }
        do {
            let squared = try clojure.square(7)
            result = "✅ 7² = \(squared)"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testFactorial() {
        guard let clojure = clojure else { return }
        do {
            let fact = try clojure.factorial(5)
            result = "✅ 5! = \(fact)"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testFilterEvens() {
        guard let clojure = clojure else { return }
        do {
            let numbers = Array(1...10)
            let evens = try clojure.filterEvens(numbers)
            result = "✅ Evens: \(evens)"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    // MARK: - Swift Interop Tests
    
    func testGetCurrentTime() {
        guard let clojure = clojure else { return }
        do {
            // Call Clojure code that calls Swift
            let output = try clojure.eval("(get-current-time)")
            if let timestamp = output as? Double {
                let date = Date(timeIntervalSince1970: timestamp)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                result = "✅ Current time from Swift: \(formatter.string(from: date))"
            } else {
                result = "✅ Timestamp: \(String(describing: output))"
            }
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testShowAlert() {
        guard let clojure = clojure else { return }
        do {
            // Call Clojure code that calls Swift to show an alert
            _ = try clojure.eval("""
            (show-alert "Hello from Clojure!")
            """)
            result = "✅ Alert triggered! Check the Alert Log section below."
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testSavePreference() {
        guard let clojure = clojure else { return }
        do {
            // Call Clojure code that calls Swift to save a preference
            _ = try clojure.eval("""
            (save-pref "clojure-test-key" "Hello from Clojure!")
            """)
            
            // Read it back to verify
            if let saved = UserDefaults.standard.string(forKey: "clojure-test-key") {
                result = "✅ Saved & verified: '\(saved)'"
            } else {
                result = "✅ Save called, but couldn't verify"
            }
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func testComplexInterop() {
        guard let clojure = clojure else { return }
        do {
            // A more complex example: use Swift functions within Clojure logic
            let output = try clojure.eval("""
            (let [timestamp (get-current-time)
                  _ (save-pref "last-run" (str timestamp))
                  _ (show-alert (str "Saved timestamp: " timestamp))]
              (str "Processed at " timestamp))
            """)
            result = "✅ Complex interop: \(String(describing: output ?? "nil"))"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
    
    func loadAndTestNewCode() {
        guard let clojure = clojure else { return }
        do {
            try clojure.loadCode(newCode)
            // Try to call the function if it exists
            let testResult = try clojure.eval("(my-function 3)")
            result = "✅ Code loaded! Test result: \(String(describing: testResult ?? "nil"))"
        } catch {
            result = "❌ Error: \(error)"
        }
    }
}

#Preview {
    ContentView()
}
