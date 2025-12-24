//
//  ScittleBridge.swift
//  ClojureScriptTest
//
//  Created by Rod Schmidt on 12/15/25.
//


import JavaScriptCore
import Foundation

class ScittleBridge {
    private let context: JSContext

    enum ScittleError: Error {
        case initializationFailed(String)
        case evaluationFailed(String)
        case invalidReturnType
    }

    init() throws {
        self.context = JSContext()!

        // Setup console with different log levels
        let logFunction: @convention(block) (String) -> Void = { message in
            print("[Scittle] \(message)")
        }
        context.setObject(logFunction, forKeyedSubscript: "log" as NSString)

        context.evaluateScript("""
        var console = { 
            log: log, 
            warn: log, 
            error: log,
            info: log,
            debug: log
        };
        """)

        // Exception handler
        context.exceptionHandler = { context, exception in
            if let exc = exception {
                print("❌ Scittle Error: \(exc.toString() ?? "unknown")")
                if let stack = exc.objectForKeyedSubscript("stack") {
                    print("Stack: \(stack)")
                }
            }
        }

        try loadScittle()
    }

    private func loadScittle() throws {
        // Load Scittle
        guard let scittlePath = Bundle.main.path(forResource: "scittle", ofType: "js") else {
            throw ScittleError.initializationFailed("scittle.js not found in bundle")
        }

        guard let scittleContent = try? String(contentsOfFile: scittlePath, encoding: .utf8) else {
            throw ScittleError.initializationFailed("Could not read scittle.js")
        }

        print("📦 Loading Scittle (\(scittleContent.count) bytes)...")

        // Mock browser globals that Scittle might expect
        context.evaluateScript("""
        var window = this;
        var global = this;
        var self = this;

        var document = {
            createElement: function(tag) {
                return {
                    setAttribute: function() {},
                    getAttribute: function() { return null; },
                    removeAttribute: function() {},
                    style: {},
                    classList: {
                        add: function() {},
                        remove: function() {},
                        contains: function() { return false; }
                    },
                    appendChild: function() {},
                    removeChild: function() {},
                    addEventListener: function() {},
                    removeEventListener: function() {},
                    innerHTML: '',
                    textContent: '',
                    value: ''
                };
            },
            createTextNode: function(text) { 
                return { textContent: text }; 
            },
            createDocumentFragment: function() {
                return { appendChild: function() {} };
            },
            querySelector: function() { return null; },
            querySelectorAll: function() { return []; },
            getElementById: function() { return null; },
            getElementsByTagName: function() { return []; },
            getElementsByClassName: function() { return []; },
            body: {
                appendChild: function() {},
                removeChild: function() {},
                style: {}
            },
            head: {
                appendChild: function() {},
                removeChild: function() {}
            },
            addEventListener: function() {},
            removeEventListener: function() {}
        };

        var navigator = {
            userAgent: 'JavaScriptCore/iOS',
            platform: 'iOS'
        };

        var location = {
            href: '',
            search: '',
            hash: '',
            pathname: '/'
        };

        var localStorage = {
            getItem: function() { return null; },
            setItem: function() {},
            removeItem: function() {},
            clear: function() {}
        };

        var sessionStorage = localStorage;

        var XMLHttpRequest = function() {
            this.open = function() {};
            this.send = function() {};
            this.setRequestHeader = function() {};
        };

        var fetch = function() {
            return Promise.reject(new Error('fetch not available'));
        };

        var setTimeout = function(fn, delay) {
            fn();
            return 0;
        };

        var setInterval = function(fn, delay) {
            return 0;
        };

        var clearTimeout = function() {};
        var clearInterval = function() {};

        console.log("✅ Browser mocks installed");
        """)

        // Now load Scittle
        context.evaluateScript(scittleContent)

        if let exception = context.exception {
            // Check if it's just the document warning, not a real error
            if let exceptionString = exception.toString() {
                if exceptionString.contains("document") && context.objectForKeyedSubscript("scittle") != nil {
                    print("⚠️ Document warning (ignored): Scittle loaded successfully")
                    context.exception = nil // Clear the exception
                } else {
                    throw ScittleError.initializationFailed("Scittle load failed: \(exceptionString)")
                }
            }
            else {
                throw ScittleError.initializationFailed("Scittle load failed for an unknown reason.")
            }
        }

        print("✅ Scittle loaded successfully")

        // Check that scittle is available
        let checkScript = """
        (function() {
            if (typeof scittle === 'undefined') {
                throw new Error("Scittle not found in global scope");
            }
            if (typeof scittle.core === 'undefined') {
                throw new Error("scittle.core not found");
            }
            if (typeof scittle.core.eval_string === 'undefined') {
                throw new Error("scittle.core.eval_string not found");
            }
            console.log("✅ Scittle.core.eval_string available");
            return true;
        })()
        """

        context.evaluateScript(checkScript)

        if let exception = context.exception {
            throw ScittleError.initializationFailed("Scittle check failed: \(exception.toString() ?? "unknown")")
        }

        print("🎉 Scittle ready for evaluation")
    }

    // MARK: - Core Evaluation
    
    func eval(_ code: String) throws -> Any? {
        print("📝 Evaluating Clojure: \(code.prefix(50))...")
        
        // Escape backticks and backslashes in the code
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        
        let evalScript = """
        (function() {
            try {
                var result = scittle.core.eval_string(`\(escapedCode)`);
                console.log("Result:", result);
                return result;
            } catch (e) {
                console.error("Eval error:", e.message || e);
                throw e;
            }
        })()
        """
        
        let result = context.evaluateScript(evalScript)
        
        if let exception = context.exception {
            throw ScittleError.evaluationFailed(exception.toString())
        }
        
        return result?.toObject()
    }
    
    // MARK: - Type-safe evaluation
    
    func evalString(_ code: String) throws -> String {
        guard let result = try eval(code) else { 
            return "nil" 
        }
        return String(describing: result)
    }
    
    func evalInt(_ code: String) throws -> Int {
        let result = try eval(code)
        
        if let intResult = result as? Int {
            return intResult
        } else if let doubleResult = result as? Double {
            return Int(doubleResult)
        } else if let stringResult = result as? String, let intResult = Int(stringResult) {
            return intResult
        }
        
        throw ScittleError.invalidReturnType
    }
    
    func evalDouble(_ code: String) throws -> Double {
        let result = try eval(code)
        
        if let doubleResult = result as? Double {
            return doubleResult
        } else if let intResult = result as? Int {
            return Double(intResult)
        } else if let stringResult = result as? String, let doubleResult = Double(stringResult) {
            return doubleResult
        }
        
        throw ScittleError.invalidReturnType
    }
    
    func evalBool(_ code: String) throws -> Bool {
        let result = try eval(code)
        
        // Handle Clojure truthiness (everything except false and nil is truthy)
        if result is NSNull { return false }
        if let bool = result as? Bool { return bool }
        if let string = result as? String {
            return string != "false" && string != "nil"
        }
        
        return true // Everything else is truthy in Clojure
    }
    
    func evalArray(_ code: String) throws -> [Any] {
        guard let result = try eval(code) as? [Any] else {
            throw ScittleError.invalidReturnType
        }
        return result
    }
    
    func evalDict(_ code: String) throws -> [String: Any] {
        guard let result = try eval(code) as? [String: Any] else {
            throw ScittleError.invalidReturnType
        }
        return result
    }
    
    // MARK: - Load namespaces
    
    func loadNamespace(_ code: String) throws {
        _ = try eval(code)
        print("✅ Namespace code evaluated")
    }
    
    // MARK: - Expose Swift functions to Clojure
    
    func exposeFunctionNoArgs(name: String, namespace: String = "user", function: @escaping () -> Any?) {
        let block: @convention(block) () -> Any? = {
            return function()
        }
        
        // Make function available in JavaScript
        context.setObject(block, forKeyedSubscript: "swift_\(name)" as NSString)
        
        // Also register it in Clojure namespace
        let registerScript = """
        (function() {
            scittle.core.eval_string(`(def \(name) (fn [] (js/swift_\(name))))`);
        })()
        """
        
        context.evaluateScript(registerScript)
        print("✅ Exposed Swift function: \(namespace)/\(name)")
    }
    
    func exposeFunctionOneArg(name: String, namespace: String = "user", function: @escaping (String) -> Any?) {
        let block: @convention(block) (String) -> Any? = { arg in
            return function(arg)
        }
        
        context.setObject(block, forKeyedSubscript: "swift_\(name)" as NSString)
        
        let registerScript = """
        (function() {
            scittle.core.eval_string(`(def \(name) (fn [x] (js/swift_\(name) x)))`);
        })()
        """
        
        context.evaluateScript(registerScript)
        print("✅ Exposed Swift function: \(namespace)/\(name)")
    }
    
    func exposeFunctionTwoArgs(name: String, namespace: String = "user", function: @escaping (String, String) -> Any?) {
        let block: @convention(block) (String, String) -> Any? = { arg1, arg2 in
            return function(arg1, arg2)
        }
        
        context.setObject(block, forKeyedSubscript: "swift_\(name)" as NSString)
        
        let registerScript = """
        (function() {
            scittle.core.eval_string(`(def \(name) (fn [x y] (js/swift_\(name) x y)))`);
        })()
        """
        
        context.evaluateScript(registerScript)
        print("✅ Exposed Swift function: \(namespace)/\(name)")
    }
}
