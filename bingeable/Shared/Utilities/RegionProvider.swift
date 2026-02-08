import Foundation

protocol RegionProviding {
    var regionCode: String { get }
}

struct DeviceRegionProvider: RegionProviding {
    var regionCode: String {
        Locale.current.region?.identifier ?? "US"
    }
}
