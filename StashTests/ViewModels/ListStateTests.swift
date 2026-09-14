
import XCTest
@testable import Stash

final class ListStateTests: XCTestCase {

    struct MockItem: Identifiable, Sendable, Equatable {
        let id: Int
        let name: String
    }

    func testInitialState() {
        let state = ListState<MockItem>()
        XCTAssertTrue(state.allItems.isEmpty)
        XCTAssertTrue(state.displayedItems.isEmpty)
        XCTAssertTrue(state.cachedItems.isEmpty)
        XCTAssertEqual(state.currentPage, 1)
        XCTAssertFalse(state.isFetching)
        XCTAssertFalse(state.isLoading)
    }

    func testUpdateContent_RecalculatesDisplayedItems() {
        var state = ListState<MockItem>()
        state.pageSize = 5
        
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        state.updateContent(items)
        
        XCTAssertEqual(state.allItems.count, 10)
        XCTAssertEqual(state.displayedItems.count, 5, "Should display only first page")
        XCTAssertEqual(state.currentPage, 2, "Should prepare next page index")
        XCTAssertTrue(state.hasMore)
        XCTAssertEqual(state.displayedItems.first?.id, 1)
        XCTAssertEqual(state.displayedItems.last?.id, 5)
    }

    func testReset_ResetsPagination() {
        var state = ListState<MockItem>()
        state.pageSize = 5
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        state.updateContent(items)
        
        // Advance to next page manually or by logic
        state.appendPage()
        
        XCTAssertEqual(state.displayedItems.count, 10)
        XCTAssertEqual(state.currentPage, 3)
        XCTAssertFalse(state.hasMore) // 10 items, pageSize 5 -> 2 pages. Page 3 has no more.

        // Reset with new items
        let newItems = (11...13).map { MockItem(id: $0, name: "Item \($0)") }
        state.reset(newItems: newItems)
        
        XCTAssertEqual(state.allItems.count, 3)
        XCTAssertEqual(state.displayedItems.count, 3)
        XCTAssertEqual(state.currentPage, 2, "Should be ready for page 2 (even if empty)")
        XCTAssertFalse(state.hasMore, "3 items < 5 pageSize, so no more")
    }

    func testAppendPage() {
        var state = ListState<MockItem>()
        state.pageSize = 3
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        state.updateContent(items) // Page 1 loaded: items 1-3
        
        XCTAssertEqual(state.displayedItems.count, 3)
        XCTAssertEqual(state.currentPage, 2)
        
        // Append Page 2 (items 4-6)
        state.appendPage()
        XCTAssertEqual(state.displayedItems.count, 6)
        XCTAssertEqual(state.displayedItems.last?.id, 6)
        XCTAssertEqual(state.currentPage, 3)
        XCTAssertTrue(state.hasMore)
        
        // Append Page 3 (items 7-9)
        state.appendPage()
        XCTAssertEqual(state.displayedItems.count, 9)
        XCTAssertEqual(state.currentPage, 4)
        
        // Append Page 4 (item 10)
        state.appendPage()
        XCTAssertEqual(state.displayedItems.count, 10)
        XCTAssertEqual(state.currentPage, 5)
        XCTAssertFalse(state.hasMore)
        
        // Try appending again (should do nothing)
        state.appendPage()
        XCTAssertEqual(state.displayedItems.count, 10)
    }
    
    func testUpdateItemInPlace() {
        var state = ListState<MockItem>()
        let item1 = MockItem(id: 1, name: "Original")
        state.updateContent([item1])
        
        let updatedItem = MockItem(id: 1, name: "Updated")
        state.updateItemInPlace(updatedItem)
        
        XCTAssertEqual(state.allItems.first?.name, "Updated")
        XCTAssertEqual(state.displayedItems.first?.name, "Updated")
    }
}
