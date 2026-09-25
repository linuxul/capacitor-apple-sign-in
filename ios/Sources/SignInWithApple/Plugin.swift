import Foundation
import Capacitor
import AuthenticationServices

@objc(SignInWithApple)
public class SignInWithApple: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SignInWithApple"
    public let jsName = "SignInWithApple"
    public let pluginMethods: [CAPPluginMethod] = [
        .async("authorize", SignInWithApple.authorize)
    ]
    static let unexpectedCredentialMessage = "The authorization did not return an Apple ID credential"

    /// Shows the Sign in with Apple sheet, which is UIKit: the method runs on the main actor and returns `{ response }`
    /// once the user has signed in. The error the request ends with, for example when the user cancels, rejects the
    /// call with its localized description.
    @MainActor
    func authorize(_ call: CAPPluginCall) async throws -> JSObject {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = getRequestedScopes(from: call)
        request.state = call.getString("state")
        request.nonce = call.getString("nonce")

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        // The controller holds its delegate weakly; this method keeps both until the request has completed.
        let answer = AuthorizationAnswer()
        authorizationController.delegate = answer

        let authorization: ASAuthorization
        do {
            authorization = try await withCheckedThrowingContinuation { continuation in
                answer.continuation = continuation
                authorizationController.performRequests()
            }
        } catch {
            throw CAPPluginError(error.localizedDescription, underlyingError: error)
        }
        withExtendedLifetime(authorizationController) {}

        // An Apple ID request always completes with an Apple ID credential; the call used to stay pending otherwise.
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw CAPPluginError(Self.unexpectedCredentialMessage)
        }
        return [
            "response": [
                "user": appleIDCredential.user,
                "email": appleIDCredential.email ?? NSNull(),
                "givenName": appleIDCredential.fullName?.givenName ?? NSNull(),
                "familyName": appleIDCredential.fullName?.familyName ?? NSNull(),
                "identityToken": appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? NSNull(),
                "authorizationCode": appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) } ?? NSNull()
            ] as JSObject
        ]
    }

    func getRequestedScopes(from call: CAPPluginCall) -> [ASAuthorization.Scope]? {
        var requestedScopes: [ASAuthorization.Scope] = []

        if let scopesStr = call.getString("scopes") {
            if scopesStr.contains("name") {
                requestedScopes.append(.fullName)
            }

            if scopesStr.contains("email") {
                requestedScopes.append(.email)
            }
        }

        if requestedScopes.count > 0 {
            return requestedScopes
        }

        return nil
    }
}

/// Receives the one answer of an authorization request: the controller calls exactly one of the two methods. Clearing
/// the continuation when it resumes makes a second call harmless.
final class AuthorizationAnswer: NSObject, ASAuthorizationControllerDelegate {
    var continuation: CheckedContinuation<ASAuthorization, Error>?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: error)
    }
}
