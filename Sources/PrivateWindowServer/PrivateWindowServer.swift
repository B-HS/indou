import Foundation

/// Namespace + capability probe for the private window-server layer.
///
/// Every symbol here is resolved defensively at runtime (see `SkyLightSymbols`)
/// so that a missing or changed private API degrades gracefully instead of
/// failing to link or crashing. Callers should always have a public-API
/// fallback path.
public enum PrivateWindowServer {
    /// Overall availability of the private (CGS/SkyLight/SLPS) layer on this OS.
    public static var isAvailable: Bool {
        SkyLightSymbols.shared.isAvailable
    }
}
