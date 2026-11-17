import Foundation
import Testing
@testable import Geist6

struct KeychainStoreTests {

  @Test func readNonexistentKeyReturnsNil() async {
    let store = InMemoryKeychainStore()
    let result = await store.read(key: "nonexistent_key_xyz")
    #expect(result == nil)
  }

  @Test func writeAndReadSameKey() async {
    let store = InMemoryKeychainStore()
    let key = "test_key_\(UUID().uuidString)"
    let value = "test_value_\(UUID().uuidString)"

    await store.write(key: key, value: value)
    let result = await store.read(key: key)

    #expect(result == value)
  }

  @Test func writeOverwritesExistingValue() async {
    let store = InMemoryKeychainStore()
    let key = "test_overwrite_\(UUID().uuidString)"

    await store.write(key: key, value: "first")
    await store.write(key: key, value: "second")

    let result = await store.read(key: key)
    #expect(result == "second")
  }

  @Test func deleteRemovesKey() async {
    let store = InMemoryKeychainStore()
    let key = "test_delete_\(UUID().uuidString)"
    await store.write(key: key, value: "to_delete")

    await store.delete(key: key)
    let result = await store.read(key: key)

    #expect(result == nil)
  }

  @Test func listAccountKeysReturnsOnlyAcctKeys() async {
    let store = InMemoryKeychainStore()
    let acctKey = "acct_\(UUID().uuidString)"
    let metaKey = "meta_\(UUID().uuidString)"
    let otherKey = "other_key_\(UUID().uuidString)"

    await store.write(key: acctKey, value: "key1")
    await store.write(key: metaKey, value: "meta1")
    await store.write(key: otherKey, value: "data1")

    let keys = await store.listAccountKeys()

    #expect(keys.contains(acctKey))
    #expect(!keys.contains(metaKey))
    #expect(!keys.contains(otherKey))

    // Cleanup
    await store.delete(key: acctKey)
    await store.delete(key: metaKey)
    await store.delete(key: otherKey)
  }

  @Test func emptyStringCanBeStored() async {
    let store = InMemoryKeychainStore()
    let key = "test_empty_\(UUID().uuidString)"

    await store.write(key: key, value: "")
    let result = await store.read(key: key)

    #expect(result == "")
  }

  @Test func specialCharactersAreStoredCorrectly() async {
    let store = InMemoryKeychainStore()
    let key = "test_special_\(UUID().uuidString)"
    let value = "key_with_emoji_🔑_and_émojis_✓_and_空格"

    await store.write(key: key, value: value)
    let result = await store.read(key: key)

    #expect(result == value)
  }
}
