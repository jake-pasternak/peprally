import AuthenticationServices
import CryptoKit
import UIKit

/// What the Apple flow hands back: the identity token + the raw nonce, which
/// Supabase needs to verify the token in `signInWithIdToken`.
struct AppleSignInResult {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
    let email: String?
}

enum AppleSignInError: Error { case badCredential }

/// Runs the native Sign in with Apple flow and reports the result. Generates a
/// nonce (raw kept, SHA256 sent to Apple) so the returned identity token can be
/// exchanged for a Supabase session.
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {
    var onResult: ((Result<AppleSignInResult, Error>) -> Void)?
    private var currentNonce: String?

    func start() {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            onResult?(.failure(AppleSignInError.badCredential))
            return
        }
        onResult?(.success(AppleSignInResult(
            idToken: idToken, nonce: nonce,
            fullName: credential.fullName, email: credential.email)))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        onResult?(.failure(error))
    }

    // MARK: nonce

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
