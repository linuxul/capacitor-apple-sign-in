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

    func testAuthorizeIsAPromiseMethod() {
        let methods = SignInWithApple().pluginMethods
        XCTAssertEqual(methods.map(\.name), ["authorize"])
        XCTAssertEqual(methods.map(\.returnType), [.promise])
    }

    // The delegate protocol is main-actor isolated, like the controller that calls it.
    @MainActor
    func testTheFirstAnswerOfTheRequestWins() async {
        let answer = AuthorizationAnswer()
        let controller = ASAuthorizationController(authorizationRequests: [ASAuthorizationAppleIDProvider().createRequest()])
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                answer.continuation = continuation
                answer.authorizationController(controller: controller, didCompleteWithError: ASAuthorizationError(.canceled))
                // A second answer must not resume the continuation again.
                answer.authorizationController(controller: controller, didCompleteWithError: ASAuthorizationError(.failed))
            }
            XCTFail("the request must end with the first error")
        } catch {
            XCTAssertEqual((error as? ASAuthorizationError)?.code, .canceled)
        }
        XCTAssertNil(answer.continuation)
    }
}
