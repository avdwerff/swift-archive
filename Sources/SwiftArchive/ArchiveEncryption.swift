//
//  ArchiveEncryption.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 04/02/2026.
//

/// Encryption methods for archives
public enum ArchiveEncryption: String, CaseIterable, Sendable {
    
    case zipTraditional = "zipcrypt"
    case aes128
    case aes192
    case aes256
    
    public var displayName: String {
        switch self {
        case .zipTraditional: return "ZIP Traditional (Weak)"
        case .aes128: return "AES-128"
        case .aes192: return "AES-192"
        case .aes256: return "AES-256"
        }
    }
    
    public var isSecure: Bool {
        self != .zipTraditional
    }
    
    public var keyBits: Int {
        switch self {
        case .zipTraditional: return 96
        case .aes128: return 128
        case .aes192: return 192
        case .aes256: return 256
        }
    }
    
    var libarchiveOption: String {
        switch self {
        case .zipTraditional: return "zip:encryption=zipcrypt"
        case .aes128: return "zip:encryption=aes128"
        case .aes192: return "zip:encryption=aes192"
        case .aes256: return "zip:encryption=aes256"
        }
    }
}
