import Foundation
import Network
import os

/// Scans the local /24 subnet for an OpenClaw gateway by probing a known port.
/// Uses NWConnection + TaskGroup for concurrent, non-blocking discovery.
/// iOS-only — returns nil immediately on watchOS.
final class SubnetScanner {

    static let shared = SubnetScanner()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "SubnetScanner")

    /// Default OpenClaw gateway port
    static let defaultPort: UInt16 = 18789

    /// Maximum concurrent connection attempts
    private let concurrency = 40

    /// Per-host connection timeout
    private let timeout: TimeInterval = 1.5

    private init() {}

    // MARK: - Public API

    /// Scan the local /24 subnet for a host listening on `port`.
    /// Returns the first responding gateway URL (e.g. "http://192.168.1.42:18789"), or nil.
    func findGateway(port: UInt16 = SubnetScanner.defaultPort) async -> String? {
        #if os(watchOS)
        return nil
        #else
        guard let localIP = getWiFiAddress() else {
            logger.warning("Cannot determine local IP — skipping subnet scan")
            return nil
        }

        let prefix = subnetPrefix(from: localIP)
        guard !prefix.isEmpty else { return nil }

        logger.info("Scanning \(prefix).1-254 on port \(port)")

        // Build candidate list, skip our own IP
        let candidates = (1...254).map { "\(prefix).\($0)" }.filter { $0 != localIP }

        return await withTaskGroup(of: String?.self, returning: String?.self) { group in
            var launched = 0
            var iterator = candidates.makeIterator()

            // Seed initial batch
            for _ in 0..<concurrency {
                guard let ip = iterator.next() else { break }
                launched += 1
                group.addTask { await self.probe(host: ip, port: port) }
            }

            // Process results, launching replacements as slots free up
            for await result in group {
                if let found = result {
                    group.cancelAll()
                    logger.info("Gateway found at \(found)")
                    return found
                }
                // Launch next candidate if available
                if let ip = iterator.next() {
                    launched += 1
                    group.addTask { await self.probe(host: ip, port: port) }
                }
            }

            logger.info("Subnet scan complete — no gateway found (\(launched) hosts probed)")
            return nil
        }
        #endif
    }

    // MARK: - Probe

    #if !os(watchOS)
    /// Attempt a TCP connection to host:port. Returns gateway URL on success, nil on failure.
    private func probe(host: String, port: UInt16) async -> String? {
        await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let tcp = NWProtocolTCP.Options()
            tcp.connectionTimeout = Int(timeout)
            let params = NWParameters(tls: nil, tcp: tcp)
            let connection = NWConnection(to: endpoint, using: params)

            var resumed = false
            let resume = { (value: String?) in
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resume("http://\(host):\(port)")
                case .failed, .cancelled:
                    resume(nil)
                case .waiting:
                    // Network path not available — give up on this host
                    resume(nil)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // Hard timeout fallback
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout + 0.5) {
                resume(nil)
            }
        }
    }

    // MARK: - Network Helpers

    /// Extract the /24 prefix from an IPv4 address (e.g. "192.168.1.42" → "192.168.1")
    private func subnetPrefix(from ip: String) -> String {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return "" }
        return parts.dropLast().joined(separator: ".")
    }

    /// Get the device's WiFi/local IPv4 address via getifaddrs.
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            let family = iface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }

            let name = String(cString: iface.ifa_name)
            // en0 = WiFi, en1 = USB Ethernet on some devices
            guard name == "en0" || name == "en1" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
                break
            }
        }
        return address
    }
    #endif
}
