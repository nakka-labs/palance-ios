import XCTest
import PalanceKit
@testable import Palance

final class ClientErrorMessageTests: XCTestCase {

    // MARK: - Offline (CHECKLIST.md UX audit [33])

    func testDirectOfflineError() {
        XCTAssertEqual(
            friendlyMessage(for: URLError(.notConnectedToInternet)),
            "No internet connection. Check your connection and try again."
        )
    }

    func testTimeoutIsAlsoOffline() {
        XCTAssertEqual(
            friendlyMessage(for: URLError(.timedOut)),
            "No internet connection. Check your connection and try again."
        )
    }

    func testWrappedOfflineError() {
        let underlying = URLError(.networkConnectionLost)
        let wrapped = NSError(domain: "com.example.transport", code: 1, userInfo: [NSUnderlyingErrorKey: underlying])
        XCTAssertEqual(
            friendlyMessage(for: wrapped),
            "No internet connection. Check your connection and try again."
        )
    }

    // MARK: - PalanceClientError — unaffected by the offline check

    func testServerErrorUsesItsOwnMessage() {
        let error = PalanceClientError.server(code: "SPLIT_MISMATCH", message: "The splits don't add up.")
        XCTAssertEqual(friendlyMessage(for: error), "The splits don't add up.")
    }

    func testNotFoundHasItsOwnMessage() {
        XCTAssertEqual(friendlyMessage(for: PalanceClientError.notFound), "That group or code couldn't be found.")
    }

    func testInvalidResponseIsGenericNotOffline() {
        XCTAssertEqual(
            friendlyMessage(for: PalanceClientError.invalidResponse),
            "Something went wrong talking to Palance. Please try again."
        )
    }

    func testDecodingFailedIsGenericNotOffline() {
        XCTAssertEqual(
            friendlyMessage(for: PalanceClientError.decodingFailed("mismatched shape")),
            "Something went wrong talking to Palance. Please try again."
        )
    }

    // MARK: - ValidationError — unaffected by the offline check

    func testValidationErrorUsesItsOwnMessage() {
        XCTAssertEqual(friendlyMessage(for: ValidationError.invalidAmount(0)), "Enter an amount greater than zero.")
    }
}
