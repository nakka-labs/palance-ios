import Testing
@testable import PalanceKit

@Suite("PalanceKit Baseline Tests")
struct PalanceKitTests {
    @Test("PalanceKit version is defined")
    func testVersion() {
        #expect(PalanceKitVersion.current == "0.1.0")
    }
}
