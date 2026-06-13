import ApplicationServices
import CoreGraphics
import Foundation

typealias MainConnectionIDFn = @convention(c) () -> Int32
typealias CopyManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
typealias CopySpacesForWindowsFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
typealias CopyWindowsWithTagsFn = @convention(c) (Int32, Int32, CFArray, Int32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Unmanaged<CFArray>?
typealias GetWindowLevelFn = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<Int32>) -> CGError
typealias AXGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
typealias SetFrontProcessFn = @convention(c) (UnsafeRawPointer, CGWindowID, UInt32) -> CGError
typealias PostEventRecordFn = @convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer) -> CGError
typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
typealias GetWindowOwnerFn = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<Int32>) -> CGError
typealias GetConnectionPSNFn = @convention(c) (Int32, UnsafeMutablePointer<ProcessSerialNumber>) -> CGError
typealias GetFrontProcessFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>) -> CGError
typealias GetConnectionIDForPSNFn = @convention(c) (Int32, UnsafePointer<ProcessSerialNumber>, UnsafeMutablePointer<Int32>) -> CGError
typealias ConnectionGetPIDFn = @convention(c) (Int32, UnsafeMutablePointer<pid_t>) -> CGError
typealias SetSymbolicHotKeyEnabledFn = @convention(c) (Int32, Bool) -> CGError

/// Lazily resolves the private SkyLight / Core Graphics Services / Accessibility
/// symbols Indou relies on. Each symbol is looked up with `dlsym`; if it is
/// missing on the current OS the corresponding accessor stays `nil` and callers
/// fall back to public APIs (graceful degradation — see docs/acknowledge/private-api.md).
final class SkyLightSymbols: @unchecked Sendable {
    static let shared = SkyLightSymbols()

    private let handle: UnsafeMutableRawPointer?

    private let mainConnectionID: MainConnectionIDFn?
    let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn?
    let copySpacesForWindows: CopySpacesForWindowsFn?
    let copyWindowsWithTags: CopyWindowsWithTagsFn?
    let getWindowLevel: GetWindowLevelFn?
    let axGetWindow: AXGetWindowFn?
    let setFrontProcessWithOptions: SetFrontProcessFn?
    let postEventRecordTo: PostEventRecordFn?
    let getProcessForPID: GetProcessForPIDFn?
    let getWindowOwner: GetWindowOwnerFn?
    let getConnectionPSN: GetConnectionPSNFn?
    let getFrontProcess: GetFrontProcessFn?
    let getConnectionIDForPSN: GetConnectionIDForPSNFn?
    let connectionGetPID: ConnectionGetPIDFn?
    let setSymbolicHotKeyEnabled: SetSymbolicHotKeyEnabledFn?

    private init() {
        let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        handle = h

        func sym<T>(_ name: String, _ type: T.Type) -> T? {
            guard let h, let ptr = dlsym(h, name) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }

        // RTLD_DEFAULT: resolve a symbol from any already-loaded image (used for
        // GetProcessForPID, which lives in CoreServices and is unavailable to Swift).
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        func globalSym<T>(_ name: String, _ type: T.Type) -> T? {
            guard let ptr = dlsym(rtldDefault, name) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }

        mainConnectionID = sym("SLSMainConnectionID", MainConnectionIDFn.self)
            ?? sym("_CGSDefaultConnection", MainConnectionIDFn.self)
        copyManagedDisplaySpaces = sym("SLSCopyManagedDisplaySpaces", CopyManagedDisplaySpacesFn.self)
            ?? sym("CGSCopyManagedDisplaySpaces", CopyManagedDisplaySpacesFn.self)
        copySpacesForWindows = sym("SLSCopySpacesForWindows", CopySpacesForWindowsFn.self)
            ?? sym("CGSCopySpacesForWindows", CopySpacesForWindowsFn.self)
        copyWindowsWithTags = sym("SLSCopyWindowsWithOptionsAndTags", CopyWindowsWithTagsFn.self)
            ?? sym("CGSCopyWindowsWithOptionsAndTags", CopyWindowsWithTagsFn.self)
        getWindowLevel = sym("SLSGetWindowLevel", GetWindowLevelFn.self)
            ?? sym("CGSGetWindowLevel", GetWindowLevelFn.self)
        // _AXUIElementGetWindow lives in the HIServices part of ApplicationServices.
        axGetWindow = sym("_AXUIElementGetWindow", AXGetWindowFn.self)
        setFrontProcessWithOptions = sym("_SLPSSetFrontProcessWithOptions", SetFrontProcessFn.self)
        postEventRecordTo = sym("SLPSPostEventRecordTo", PostEventRecordFn.self)
        getProcessForPID = globalSym("GetProcessForPID", GetProcessForPIDFn.self)
        // GetProcessForPID is gone on macOS 26; PSN is derived from the window's
        // owning connection instead (SLSGetWindowOwner → SLSGetConnectionPSN).
        getWindowOwner = sym("SLSGetWindowOwner", GetWindowOwnerFn.self)
            ?? sym("CGSGetWindowOwner", GetWindowOwnerFn.self)
        getConnectionPSN = sym("SLSGetConnectionPSN", GetConnectionPSNFn.self)
            ?? sym("CGSGetConnectionPSN", GetConnectionPSNFn.self)
        getFrontProcess = sym("_SLPSGetFrontProcess", GetFrontProcessFn.self)
        getConnectionIDForPSN = sym("SLSGetConnectionIDForPSN", GetConnectionIDForPSNFn.self)
        connectionGetPID = sym("SLSConnectionGetPID", ConnectionGetPIDFn.self)
        setSymbolicHotKeyEnabled = sym("CGSSetSymbolicHotKeyEnabled", SetSymbolicHotKeyEnabledFn.self)
    }

    /// The pid the window server currently considers front, or -1.
    func frontProcessPID() -> pid_t {
        guard let getFront = getFrontProcess, let getCID = getConnectionIDForPSN, let getPID = connectionGetPID else { return -1 }
        var psn = ProcessSerialNumber()
        guard getFront(&psn) == .success else { return -1 }
        var cid: Int32 = 0
        let ok = withUnsafePointer(to: &psn) { getCID(connectionID, $0, &cid) == .success }
        guard ok else { return -1 }
        var pid: pid_t = 0
        guard getPID(cid, &pid) == .success else { return -1 }
        return pid
    }

    var isAvailable: Bool { handle != nil && mainConnectionID != nil }

    /// The main Core Graphics Services connection id, or 0 when unavailable.
    var connectionID: Int32 { mainConnectionID?() ?? 0 }
}
