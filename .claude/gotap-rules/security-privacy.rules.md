# Security and Privacy Rules

## Data Protection

### DO: Keychain Usage
✅ **ALWAYS use Keychain for sensitive data storage**

```swift
import Security

class KeychainManager {
    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }
    
    static func save(password: String, account: String) throws {
        let data = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    static func retrieve(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.noPassword
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return password
    }
    
    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}
```

### DO: Biometric Authentication
✅ **ALWAYS implement biometric authentication for sensitive features**

```swift
import LocalAuthentication

class BiometricManager: ObservableObject {
    enum BiometricError: Error {
        case notAvailable
        case authenticationFailed
        case userCancel
    }
    
    @Published var isAuthenticated = false
    
    func authenticateUser() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }
        
        let reason = "Authenticate to access sensitive information"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                await MainActor.run {
                    isAuthenticated = true
                }
            }
        } catch {
            throw BiometricError.authenticationFailed
        }
    }
}

// Usage in SwiftUI
struct SecureView: View {
    @StateObject private var biometricManager = BiometricManager()
    
    var body: some View {
        Group {
            if biometricManager.isAuthenticated {
                SensitiveContentView()
            } else {
                Button("Authenticate") {
                    Task {
                        try await biometricManager.authenticateUser()
                    }
                }
            }
        }
        .onAppear {
            Task {
                try await biometricManager.authenticateUser()
            }
        }
    }
}
```

## Network Security

### DO: Certificate Pinning
✅ **ALWAYS implement certificate pinning for production apps**

```swift
import Network

class SecureNetworkManager: ObservableObject {
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        
        self.session = URLSession(
            configuration: configuration,
            delegate: NetworkDelegate(),
            delegateQueue: nil
        )
    }
    
    func performSecureRequest<T: Codable>(
        url: URL,
        expecting: T.Type
    ) async throws -> T {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

class NetworkDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Implement certificate pinning
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Verify certificate against pinned certificates
        let certificates = Bundle.main.paths(forResourcesOfType: "cer", inDirectory: nil)
        
        for certPath in certificates {
            if let localCertData = NSData(contentsOfFile: certPath),
               let localCert = SecCertificateCreateWithData(nil, localCertData) {
                
                let serverCertData = SecCertificateCopyData(
                    SecTrustGetCertificateAtIndex(serverTrust, 0)!
                )
                
                if CFEqual(localCertData, serverCertData) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return
                }
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
}
```

### DO: App Transport Security
✅ **ALWAYS enable App Transport Security**

```xml
<!-- Info.plist -->
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>api.yourdomain.com</key>
            <dict>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <false/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.2</string>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
```

## Privacy Manifest

### DO: Privacy Manifest Compliance
✅ **ALWAYS create and maintain privacy manifest (iOS 17+)**

```json
{
  "NSPrivacyAccessedAPITypes": [
    {
      "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
      "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]
    },
    {
      "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp",
      "NSPrivacyAccessedAPITypeReasons": ["C617.1"]
    }
  ],
  "NSPrivacyCollectedDataTypes": [
    {
      "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeEmailAddress",
      "NSPrivacyCollectedDataTypeLinked": true,
      "NSPrivacyCollectedDataTypeTracking": false,
      "NSPrivacyCollectedDataTypePurposes": ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]
    }
  ],
  "NSPrivacyTrackingDomains": [],
  "NSPrivacyTracking": false
}
```

### DO: Privacy-Sensitive UI
✅ **ALWAYS mark sensitive UI content appropriately**

```swift
struct PrivacySensitiveView: View {
    @State private var userEmail = ""
    @State private var creditCardNumber = ""
    @State private var socialSecurityNumber = ""
    
    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Email", text: $userEmail)
                    .privacySensitive()
                
                TextField("Credit Card", text: $creditCardNumber)
                    .privacySensitive()
                    .textContentType(.creditCardNumber)
                
                SecureField("SSN", text: $socialSecurityNumber)
                    .privacySensitive()
            }
        }
        .onAppear {
            // Mark the entire view as privacy sensitive
            UIScreen.main.captured = true
        }
    }
}
```

## Data Encryption

### DO: Data Encryption at Rest
✅ **ALWAYS encrypt sensitive data at rest**

```swift
import CryptoKit

class DataEncryptionManager {
    private let key = SymmetricKey(size: .bits256)
    
    func encrypt(data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    func decrypt(data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        let encryptedData = try encrypt(data: data)
        return encryptedData.base64EncodedString()
    }
    
    func decryptString(_ encryptedString: String) throws -> String {
        guard let data = Data(base64Encoded: encryptedString) else {
            throw EncryptionError.invalidData
        }
        
        let decryptedData = try decrypt(data: data)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        return string
    }
}

enum EncryptionError: Error {
    case invalidData
    case encryptionFailed
    case decryptionFailed
}
```

## Secure Communication

### DO: API Request Security
✅ **ALWAYS implement secure API communication**

```swift
class SecureAPIClient {
    private let session: URLSession
    private let apiKey: String
    
    init() {
        // Retrieve API key from Keychain
        self.apiKey = try! KeychainManager.retrieve(account: "api_key")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: configuration)
    }
    
    func performSecureRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        expecting: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(Config.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Add request signature
        let signature = try generateRequestSignature(for: request, body: body)
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func generateRequestSignature(for request: URLRequest, body: Data?) throws -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString
        
        var signatureData = "\(request.httpMethod ?? "GET")\(request.url?.absoluteString ?? "")\(timestamp)\(nonce)"
        
        if let body = body {
            signatureData += String(data: body, encoding: .utf8) ?? ""
        }
        
        guard let data = signatureData.data(using: .utf8) else {
            throw APIError.signatureError
        }
        
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: apiKey.data(using: .utf8)!))
        
        return Data(signature).base64EncodedString()
    }
}
```

## Input Validation

### DO: Input Sanitization
✅ **ALWAYS validate and sanitize user input**

```swift
class InputValidator {
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    static func sanitizeInput(_ input: String) -> String {
        // Remove potentially harmful characters
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(.punctuationCharacters)
        return String(input.unicodeScalars.filter { allowedCharacters.contains($0) })
    }
    
    static func validatePassword(_ password: String) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if password.count < 8 {
            errors.append(.passwordTooShort)
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            errors.append(.passwordMissingUppercase)
        }
        
        if !password.contains(where: { $0.isLowercase }) {
            errors.append(.passwordMissingLowercase)
        }
        
        if !password.contains(where: { $0.isNumber }) {
            errors.append(.passwordMissingNumber)
        }
        
        if !password.contains(where: { "!@#$%^&*".contains($0) }) {
            errors.append(.passwordMissingSpecialChar)
        }
        
        return errors
    }
}

enum ValidationError: Error, LocalizedError {
    case passwordTooShort
    case passwordMissingUppercase
    case passwordMissingLowercase
    case passwordMissingNumber
    case passwordMissingSpecialChar
    
    var errorDescription: String? {
        switch self {
        case .passwordTooShort:
            return "Password must be at least 8 characters long"
        case .passwordMissingUppercase:
            return "Password must contain at least one uppercase letter"
        case .passwordMissingLowercase:
            return "Password must contain at least one lowercase letter"
        case .passwordMissingNumber:
            return "Password must contain at least one number"
        case .passwordMissingSpecialChar:
            return "Password must contain at least one special character"
        }
    }
}
```

## Secure Storage

### DO: Secure Database Configuration
✅ **ALWAYS configure secure database settings**

```swift
import SwiftData

@Model
class SecureUser {
    @Attribute(.unique) var id: UUID
    var email: String
    var hashedPassword: String
    var createdAt: Date
    
    init(email: String, password: String) {
        self.id = UUID()
        self.email = email
        self.hashedPassword = SecureUser.hashPassword(password)
        self.createdAt = Date()
    }
    
    static func hashPassword(_ password: String) -> String {
        guard let data = password.data(using: .utf8) else { return "" }
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
class SecureDataManager {
    private let container: ModelContainer
    
    init() {
        let schema = Schema([SecureUser.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none // Disable CloudKit for sensitive data
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create secure container: \(error)")
        }
    }
    
    func saveUser(_ user: SecureUser) throws {
        let context = container.mainContext
        context.insert(user)
        try context.save()
    }
}
```

## Logging Security

### DO: Secure Logging
✅ **ALWAYS implement secure logging practices**

```swift
import os

class SecureLogger {
    private let logger = Logger(subsystem: "com.yourapp.security", category: "security")
    
    func logSecurityEvent(_ event: SecurityEvent, metadata: [String: Any] = [:]) {
        var sanitizedMetadata = metadata
        
        // Remove sensitive information
        sanitizedMetadata.removeValue(forKey: "password")
        sanitizedMetadata.removeValue(forKey: "token")
        sanitizedMetadata.removeValue(forKey: "api_key")
        
        logger.warning("Security Event: \(event.description) - \(sanitizedMetadata)")
    }
    
    func logAuthenticationAttempt(success: Bool, userID: String? = nil) {
        if success {
            logger.info("Authentication successful for user: \(userID ?? "unknown")")
        } else {
            logger.warning("Authentication failed")
        }
    }
    
    func logDataAccess(resource: String, userID: String) {
        logger.info("Data access - Resource: \(resource), User: \(userID)")
    }
}

enum SecurityEvent {
    case unauthorizedAccess
    case suspiciousActivity
    case dataExfiltration
    case malformedRequest
    
    var description: String {
        switch self {
        case .unauthorizedAccess:
            return "Unauthorized access attempt"
        case .suspiciousActivity:
            return "Suspicious activity detected"
        case .dataExfiltration:
            return "Potential data exfiltration"
        case .malformedRequest:
            return "Malformed request received"
        }
    }
}
```

## Permission Management

### DO: Runtime Permission Requests
✅ **ALWAYS request permissions with proper justification**

```swift
import PhotosUI

class PermissionManager: ObservableObject {
    @Published var cameraPermission: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermission: PHAuthorizationStatus = .notDetermined
    
    func requestCameraPermission() async {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.photoLibraryPermission = status
        }
    }
}

struct PermissionRequestView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Camera Access")
                .font(.headline)
            
            Text("This app needs camera access to take photos for your profile.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Grant Camera Access") {
                Task {
                    await permissionManager.requestCameraPermission()
                }
            }
            .disabled(permissionManager.cameraPermission == .authorized)
        }
        .padding()
    }
}
```

## Anti-Patterns to Avoid

### DON'T: Security Mistakes
❌ **NEVER store sensitive data in UserDefaults**
❌ **NEVER log sensitive information**
❌ **NEVER skip input validation**
❌ **NEVER use hardcoded API keys**
❌ **NEVER ignore certificate validation**
❌ **NEVER store passwords in plain text**
❌ **NEVER skip biometric authentication for sensitive features**

### DON'T: Privacy Violations
❌ **NEVER access user data without permission**
❌ **NEVER track users without consent**
❌ **NEVER skip privacy manifest updates**
❌ **NEVER ignore data retention policies**
❌ **NEVER share sensitive data without encryption**

## Security Checklist

### DO: Regular Security Audits
✅ **ALWAYS follow security checklist**

- [ ] All sensitive data stored in Keychain
- [ ] Biometric authentication implemented
- [ ] Certificate pinning configured
- [ ] App Transport Security enabled
- [ ] Privacy manifest up to date
- [ ] Input validation implemented
- [ ] Secure logging in place
- [ ] Permission requests justified
- [ ] Data encryption at rest
- [ ] Secure API communication
- [ ] Regular security testing
- [ ] Third-party library security review