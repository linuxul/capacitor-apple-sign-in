import XCTest
import AuthenticationServices
import Capacitor
@testable import SignInWithApple

class PluginTests: XCTestCase {
    private func call(scopes: String?) -> CAPPluginCall {
        var options: JSObject = [:]
        if let scopes = scopes {
            options["scopes"] = scopes
        }
        return CAPPluginCall(callbackId: "test", methodName: "authorize", options: options, success: { (_, _) in }, error: { _ in })
    }

    func testRequestedScopes() {
        let plugin = SignInWithApple()

        XCTAssertEqual([.fullName, .email], plugin.getRequestedScopes(from: call(scopes: "email name")))
        XCTAssertEqual([.email], plugin.getRequestedScopes(from: call(scopes: "email")))
        XCTAssertNil(plugin.getRequestedScopes(from: call(scopes: "other")))
        XCTAssertNil(plugin.getRequestedScopes(from: call(scopes: nil)))
    }
}
