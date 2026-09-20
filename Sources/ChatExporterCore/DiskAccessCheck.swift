import Darwin
import Foundation

/// A conservative capability probe, not a public TCC authorization-status API.
/// Opens the user's protected TCC file read-only, without reading its contents.
public enum DiskAccessCheck {
    public enum Status: Equatable, Sendable {
        case available
        case denied
        case unavailable(Int32)
    }

    public static func classify(descriptor: Int32, error: Int32) -> Status {
        if descriptor >= 0 { return .available }
        if error == EACCES || error == EPERM { return .denied }
        return .unavailable(error)
    }

    public static func current() -> Status {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db").path
        let descriptor = open(path, O_RDONLY | O_CLOEXEC)
        let savedError = errno
        if descriptor >= 0 { close(descriptor) }
        return classify(descriptor: descriptor, error: savedError)
    }
}
