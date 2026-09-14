import Foundation
import Combine

/// A property wrapper that combines @Published and @Persisted for reactive, persistent properties.
///
/// This is designed to be used in ObservableObject ViewModels where you want both
/// persistence and Combine publisher functionality. It automatically saves changes to UserDefaults
/// and publishes updates through Combine.
///
/// Supports RawRepresentable types (enums) and basic UserDefaults types (String, Int, Bool, etc.)
///
/// Usage in a ViewModel:
/// ```swift
/// @MainActor
/// final class MyViewModel: ObservableObject {
///     @PublishedPersisted(key: "SceneSortType", defaultValue: .createdAt)
///     var sortType: SceneSortType
/// }
/// ```
@propertyWrapper
class PublishedPersisted<Value> {
    private let key: String
    private let defaultValue: Value
    private let storage: UserDefaults
    private let load: (String, UserDefaults) -> Value?
    private let save: (Value, String, UserDefaults) -> Void
    
    @Published private var value: Value
    
    var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            save(newValue, key, storage)
        }
    }
    
    var projectedValue: Published<Value>.Publisher {
        $value
    }
    
    /// Initializes the property wrapper with a key and default value.
    ///
    /// - Parameters:
    ///   - key: The UserDefaults key to store the value under
    ///   - defaultValue: The default value to use if no value exists in UserDefaults
    ///   - storage: The UserDefaults instance to use (defaults to .standard)
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) where Value: RawRepresentable, Value.RawValue == String {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        
        // Load and save closures for RawRepresentable with String raw value
        self.load = { key, storage in
            guard let rawValue = storage.string(forKey: key) else { return nil }
            return Value(rawValue: rawValue)
        }
        self.save = { value, key, storage in
            storage.set(value.rawValue, forKey: key)
        }
        
        let initialValue = self.load(key, storage) ?? defaultValue
        self._value = Published(initialValue: initialValue)
    }
    
    /// Initializes the property wrapper for RawRepresentable types with Int raw values
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) where Value: RawRepresentable, Value.RawValue == Int {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        
        self.load = { key, storage in
            guard let rawValue = storage.object(forKey: key) as? Int else { return nil }
            return Value(rawValue: rawValue)
        }
        self.save = { value, key, storage in
            storage.set(value.rawValue, forKey: key)
        }
        
        let initialValue = self.load(key, storage) ?? defaultValue
        self._value = Published(initialValue: initialValue)
    }
    
    /// Initializes the property wrapper for String values
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) where Value == String {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        
        self.load = { key, storage in
            storage.string(forKey: key) as? Value
        }
        self.save = { value, key, storage in
            storage.set(value, forKey: key)
        }
        
        let initialValue = self.load(key, storage) ?? defaultValue
        self._value = Published(initialValue: initialValue)
    }
    
    /// Initializes the property wrapper for Int values
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) where Value == Int {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        
        self.load = { key, storage in
            storage.object(forKey: key) as? Value
        }
        self.save = { value, key, storage in
            storage.set(value, forKey: key)
        }
        
        let initialValue = self.load(key, storage) ?? defaultValue
        self._value = Published(initialValue: initialValue)
    }
    
    /// Initializes the property wrapper for Bool values
    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) where Value == Bool {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        
        self.load = { key, storage in
            storage.object(forKey: key) as? Value
        }
        self.save = { value, key, storage in
            storage.set(value, forKey: key)
        }
        
        let initialValue = self.load(key, storage) ?? defaultValue
        self._value = Published(initialValue: initialValue)
    }
}
