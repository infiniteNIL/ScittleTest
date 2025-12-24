//
//  ClojureAPI.swift
//  ClojureScriptTest
//
//  Created by Rod Schmidt on 12/15/25.
//


import Foundation

class ClojureAPI {
    private let scittle: ScittleBridge
    private var alertCallback: ((String) -> Void)?
    
    init() throws {
        self.scittle = try ScittleBridge()
        try setupEnvironment()
    }
    
    func setAlertCallback(_ callback: @escaping (String) -> Void) {
        self.alertCallback = callback
    }
    
    private func setupEnvironment() throws {
        // Expose Swift functions to Clojure
        scittle.exposeFunctionNoArgs(name: "get-current-time") {
            let timestamp = Date().timeIntervalSince1970
            print("📱 Swift: Returning current time: \(timestamp)")
            return timestamp
        }
        
        scittle.exposeFunctionOneArg(name: "show-alert") { [weak self] title in
            print("📱 Swift: Showing alert: \(title)")
            DispatchQueue.main.async {
                self?.alertCallback?(title)
            }
            return true
        }
        
        scittle.exposeFunctionTwoArgs(name: "save-pref") { key, value in
            print("📱 Swift: Saving preference: \(key) = \(value)")
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        // Load your Clojure functions
        try scittle.loadNamespace("""
        (ns user)
        
        (defn greet [name]
          (str "Hello, " name "!"))
        
        (defn calculate [op x y]
          (case op
            :add (+ x y)
            :subtract (- x y)
            :multiply (* x y)
            :divide (/ x y)
            :power (js/Math.pow x y)
            0))
        
        (def counter (atom 0))
        
        (defn increment-counter []
          (swap! counter inc))
        
        (defn get-counter []
          @counter)
        
        (defn reset-counter []
          (reset! counter 0))
        
        (defn square [x]
          (* x x))
        
        (defn factorial [n]
          (if (<= n 1)
            1
            (* n (factorial (dec n)))))
        
        ;; Return as JS array
        (defn filter-evens [nums]
          (clj->js (vec (filter even? nums))))
        
        (defn sum [nums]
          (reduce + nums))
        
        ;; Helper to convert any Clojure collection to JS array
        (defn ->js-array [coll]
          (clj->js (vec coll)))
        
        ;; Example functions that call Swift
        (defn save-timestamp []
          (let [ts (get-current-time)]
            (save-pref "last-timestamp" (str ts))
            ts))
        
        (defn notify-user [message]
          (show-alert message))
        
        (defn save-and-notify [key value]
          (save-pref key value)
          (show-alert (str "Saved " key)))
        """)
        
        print("✅ Clojure environment ready")
    }
    
    // MARK: - Convenience Methods
    
    func greet(name: String) throws -> String {
        try scittle.evalString("(user/greet \"\(name)\")")
    }
    
    func calculate(operation: String, x: Double, y: Double) throws -> Double {
        try scittle.evalDouble("(user/calculate :\(operation) \(x) \(y))")
    }
    
    func incrementCounter() throws -> Int {
        try scittle.evalInt("(user/increment-counter)")
    }
    
    func getCounter() throws -> Int {
        try scittle.evalInt("(user/get-counter)")
    }
    
    func resetCounter() throws -> Int {
        try scittle.evalInt("(user/reset-counter)")
    }
    
    func square(_ x: Int) throws -> Int {
        try scittle.evalInt("(user/square \(x))")
    }
    
    func factorial(_ n: Int) throws -> Int {
        try scittle.evalInt("(user/factorial \(n))")
    }
    
    func filterEvens(_ numbers: [Int]) throws -> [Int] {
        let numsStr = numbers.map(String.init).joined(separator: " ")
        let result = try scittle.evalArray("(user/filter-evens [\(numsStr)])")
        return result.compactMap { $0 as? Int }
    }
    
    func sum(_ numbers: [Int]) throws -> Int {
        let numsStr = numbers.map(String.init).joined(separator: " ")
        return try scittle.evalInt("(user/sum [\(numsStr)])")
    }
    
    // MARK: - Dynamic Evaluation
    
    func eval(_ code: String) throws -> Any? {
        try scittle.eval(code)
    }
    
    func loadCode(_ code: String) throws {
        try scittle.loadNamespace(code)
    }
}