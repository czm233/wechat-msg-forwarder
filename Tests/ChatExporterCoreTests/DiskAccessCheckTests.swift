import Darwin
import Testing
@testable import ChatExporterCore

@Test func permissionProbeDistinguishesDenialFromOtherFailures() {
    #expect(DiskAccessCheck.classify(descriptor: 3, error: EPERM) == .available)
    #expect(DiskAccessCheck.classify(descriptor: -1, error: EPERM) == .denied)
    #expect(DiskAccessCheck.classify(descriptor: -1, error: EACCES) == .denied)
    #expect(DiskAccessCheck.classify(descriptor: -1, error: ENOENT) == .unavailable(ENOENT))
    #expect(DiskAccessCheck.classify(descriptor: -1, error: EMFILE) == .unavailable(EMFILE))
}
