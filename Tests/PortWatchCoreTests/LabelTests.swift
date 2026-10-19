import XCTest
@testable import PortWatchCore

final class LabelTests: XCTestCase {

    func testWorktreeYieldsRepositoryAndWorktreeName() {
        let label = DevServerClassifier.label(
            workingDirectory: "/Users/a/projects/shop-app/.worktrees/checkout-redesign",
            executableName: "node"
        )
        XCTAssertEqual(label, "shop-app/checkout-redesign")
    }

    func testWorktreeSubdirectoryStillYieldsTheWorktreeName() {
        let label = DevServerClassifier.label(
            workingDirectory: "/Users/a/projects/shop-app/.worktrees/checkout-redesign/apps/mobile",
            executableName: "node"
        )
        XCTAssertEqual(label, "shop-app/checkout-redesign")
    }

    func testPlainCheckoutYieldsDirectoryName() {
        let label = DevServerClassifier.label(
            workingDirectory: "/Users/a/projects/shop-app", executableName: "node"
        )
        XCTAssertEqual(label, "shop-app")
    }

    func testRootDirectoryFallsBackToExecutable() {
        XCTAssertEqual(
            DevServerClassifier.label(workingDirectory: "/", executableName: "adb"), "adb"
        )
    }

    func testMissingDirectoryFallsBackToExecutable() {
        XCTAssertEqual(
            DevServerClassifier.label(workingDirectory: "", executableName: "postgres"), "postgres"
        )
    }

    func testTrailingSlashDoesNotProduceEmptyLabel() {
        XCTAssertEqual(
            DevServerClassifier.label(workingDirectory: "/Users/a/projects/monorepo/", executableName: "bun"),
            "monorepo"
        )
    }

    func testWorktreesDirectoryWithoutANamedWorktreeFallsBack() {
        let label = DevServerClassifier.label(
            workingDirectory: "/Users/a/projects/shop-app/.worktrees", executableName: "node"
        )
        XCTAssertEqual(label, ".worktrees")
    }
}
