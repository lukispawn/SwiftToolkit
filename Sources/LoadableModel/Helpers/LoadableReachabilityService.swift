//
//  LoadableReachabilityService.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Combine
import Foundation

enum LoadableReachabilityFactory {
    static var defaultManager: LoadableReachabilityType? {
        nil
        /*LoadableReachability.shared*/
    }
}

enum ReachabilityConnectionStatus {
    case none
    case unavailable, wifi, cellular
    public var description: String {
        switch self {
        case .cellular: return "Cellular"
        case .wifi: return "WiFi"
        case .unavailable: return "No Connection"
        case .none: return "unavailable"
        }
    }
}

protocol LoadableReachabilityType {
    func start()
    var status: ReachabilityConnectionStatus { get }
    var reachabilityChanged: AnyPublisher<ReachabilityConnectionStatus, Never> { get }
}

