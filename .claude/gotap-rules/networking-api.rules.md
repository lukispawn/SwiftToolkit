# Networking and API Rules

## API Client Architecture

### DO: Protocol-Based API Design
✅ **ALWAYS implement protocol-based API clients**

```swift
protocol APIClientProtocol {
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Data?
    ) async throws -> T
}

class APIClient: APIClientProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let authenticationManager: AuthenticationManager
    
    init(baseURL: URL, authenticationManager: AuthenticationManager) {
        self.baseURL = baseURL
        self.authenticationManager = authenticationManager
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
    }
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = await authenticationManager.validToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        try handleHTTPResponse(httpResponse, data: data)
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            break
        case 400:
            throw APIError.badRequest
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(response.statusCode)
        }
    }
}
```

### DO: Endpoint Definition
✅ **ALWAYS define endpoints with proper structure**

```swift
enum APIEndpoint {
    case users
    case user(id: String)
    case createUser
    case updateUser(id: String)
    case deleteUser(id: String)
    case userPosts(userID: String)
    
    var path: String {
        switch self {
        case .users:
            return "/users"
        case .user(let id):
            return "/users/\(id)"
        case .createUser:
            return "/users"
        case .updateUser(let id):
            return "/users/\(id)"
        case .deleteUser(let id):
            return "/users/\(id)"
        case .userPosts(let userID):
            return "/users/\(userID)/posts"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .users, .user, .userPosts:
            return .GET
        case .createUser:
            return .POST
        case .updateUser:
            return .PUT
        case .deleteUser:
            return .DELETE
        }
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}
```

## Error Handling

### DO: Comprehensive Error Handling
✅ **ALWAYS implement comprehensive error handling**

```swift
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case networkError(Error)
    case decodingError(Error)
    case unknown(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .noData:
            return "No data received"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .unknown(let code):
            return "Unknown error with code: \(code)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .serverError, .networkError:
            return true
        default:
            return false
        }
    }
}
```

### DO: Retry Logic
✅ **ALWAYS implement retry logic for transient failures**

```swift
class RetryableAPIClient: APIClientProtocol {
    private let apiClient: APIClient
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    init(apiClient: APIClient, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.apiClient = apiClient
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await apiClient.request(
                    endpoint: endpoint,
                    method: method,
                    body: body
                )
            } catch let error as APIError {
                lastError = error
                
                if !error.isRetryable || attempt == maxRetries {
                    throw error
                }
                
                // Exponential backoff
                let delay = retryDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError ?? APIError.unknown(0)
    }
}
```

## Request/Response Interceptors

### DO: Request Interceptors
✅ **ALWAYS implement request interceptors for common functionality**

```swift
protocol RequestInterceptor {
    func intercept(request: URLRequest) async throws -> URLRequest
}

class AuthenticationInterceptor: RequestInterceptor {
    private let authManager: AuthenticationManager
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        if let token = await authManager.validToken() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return modifiedRequest
    }
}

class LoggingInterceptor: RequestInterceptor {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        logger.info("API Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        
        if let body = request.httpBody {
            logger.debug("Request body: \(String(data: body, encoding: .utf8) ?? "")")
        }
        
        return request
    }
}
```

### DO: Response Interceptors
✅ **ALWAYS implement response interceptors for monitoring**

```swift
protocol ResponseInterceptor {
    func intercept(response: URLResponse, data: Data) async throws -> Data
}

class ErrorHandlingInterceptor: ResponseInterceptor {
    func intercept(response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            // Handle token refresh
            await AuthenticationManager.shared.refreshToken()
            throw APIError.unauthorized
        }
        
        return data
    }
}

class ResponseLoggingInterceptor: ResponseInterceptor {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func intercept(response: URLResponse, data: Data) async throws -> Data {
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("API Response: \(httpResponse.statusCode)")
        }
        
        logger.debug("Response data: \(String(data: data, encoding: .utf8) ?? "")")
        
        return data
    }
}
```

## Offline Support

### DO: Offline Queue Management
✅ **ALWAYS implement offline request queuing**

```swift
@Observable
class OfflineRequestManager {
    private var pendingRequests: [OfflineRequest] = []
    private let storage: OfflineStorage
    private let networkMonitor: NetworkMonitor
    
    init(storage: OfflineStorage, networkMonitor: NetworkMonitor) {
        self.storage = storage
        self.networkMonitor = networkMonitor
        
        loadPendingRequests()
        observeNetworkStatus()
    }
    
    func queueRequest(_ request: OfflineRequest) {
        pendingRequests.append(request)
        storage.save(requests: pendingRequests)
        
        if networkMonitor.isConnected {
            Task {
                await processPendingRequests()
            }
        }
    }
    
    private func processPendingRequests() async {
        guard networkMonitor.isConnected else { return }
        
        let requestsToProcess = pendingRequests
        
        for request in requestsToProcess {
            do {
                try await executeRequest(request)
                removePendingRequest(request)
            } catch {
                // Log error but continue processing other requests
                print("Failed to process offline request: \(error)")
            }
        }
    }
    
    private func executeRequest(_ request: OfflineRequest) async throws {
        // Execute the actual API request
        let apiClient = APIClient.shared
        let _: EmptyResponse = try await apiClient.request(
            endpoint: request.endpoint,
            method: request.method,
            body: request.body
        )
    }
    
    private func removePendingRequest(_ request: OfflineRequest) {
        pendingRequests.removeAll { $0.id == request.id }
        storage.save(requests: pendingRequests)
    }
    
    private func loadPendingRequests() {
        pendingRequests = storage.loadRequests()
    }
    
    private func observeNetworkStatus() {
        networkMonitor.onNetworkStatusChange = { [weak self] isConnected in
            if isConnected {
                Task {
                    await self?.processPendingRequests()
                }
            }
        }
    }
}

struct OfflineRequest: Codable, Identifiable {
    let id = UUID()
    let endpoint: String
    let method: String
    let body: Data?
    let timestamp: Date
}
```

## Caching Strategy

### DO: Response Caching
✅ **ALWAYS implement intelligent response caching**

```swift
class CachedAPIClient: APIClientProtocol {
    private let apiClient: APIClient
    private let cache: ResponseCache
    private let cachePolicy: CachePolicy
    
    init(apiClient: APIClient, cache: ResponseCache, cachePolicy: CachePolicy) {
        self.apiClient = apiClient
        self.cache = cache
        self.cachePolicy = cachePolicy
    }
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        let cacheKey = generateCacheKey(endpoint: endpoint, method: method, body: body)
        
        // Check cache for GET requests
        if method == .GET, let cachedResponse: T = cache.get(key: cacheKey) {
            if !cache.isExpired(key: cacheKey) {
                return cachedResponse
            }
        }
        
        // Make network request
        let response: T = try await apiClient.request(
            endpoint: endpoint,
            method: method,
            body: body
        )
        
        // Cache GET responses
        if method == .GET {
            cache.set(key: cacheKey, value: response, ttl: cachePolicy.ttl(for: endpoint))
        }
        
        return response
    }
    
    private func generateCacheKey(endpoint: APIEndpoint, method: HTTPMethod, body: Data?) -> String {
        var key = "\(method.rawValue):\(endpoint.path)"
        
        if let body = body {
            key += ":\(body.base64EncodedString())"
        }
        
        return key
    }
}

class ResponseCache {
    private var cache: [String: CachedItem] = [:]
    private let queue = DispatchQueue(label: "response.cache", attributes: .concurrent)
    
    func get<T: Codable>(key: String) -> T? {
        return queue.sync {
            guard let item = cache[key],
                  let data = item.data else {
                return nil
            }
            
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }
    
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            guard let data = try? JSONEncoder().encode(value) else { return }
            
            self.cache[key] = CachedItem(
                data: data,
                expirationDate: Date().addingTimeInterval(ttl)
            )
        }
    }
    
    func isExpired(key: String) -> Bool {
        return queue.sync {
            guard let item = cache[key] else { return true }
            return Date() > item.expirationDate
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

struct CachedItem {
    let data: Data
    let expirationDate: Date
}
```

## Mock Data for Testing

### DO: Mock API Implementation
✅ **ALWAYS provide mock implementations for testing**

```swift
class MockAPIClient: APIClientProtocol {
    private let delay: TimeInterval
    private let shouldFail: Bool
    
    init(delay: TimeInterval = 0.1, shouldFail: Bool = false) {
        self.delay = delay
        self.shouldFail = shouldFail
    }
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldFail {
            throw APIError.serverError
        }
        
        // Return mock data based on endpoint
        switch endpoint {
        case .users:
            let mockUsers = [
                User(id: "1", name: "John Doe", email: "john@example.com"),
                User(id: "2", name: "Jane Smith", email: "jane@example.com")
            ]
            return mockUsers as! T
            
        case .user(let id):
            let mockUser = User(id: id, name: "Mock User", email: "mock@example.com")
            return mockUser as! T
            
        default:
            throw APIError.notFound
        }
    }
}

// Usage in tests
@Test
func testUserViewModel() async {
    let mockClient = MockAPIClient()
    let viewModel = UserViewModel(apiClient: mockClient)
    
    await viewModel.loadUsers()
    
    #expect(viewModel.users.count == 2)
    #expect(viewModel.users.first?.name == "John Doe")
}
```

## API Versioning

### DO: API Version Management
✅ **ALWAYS implement proper API versioning**

```swift
enum APIVersion: String {
    case v1 = "v1"
    case v2 = "v2"
    
    var basePath: String {
        return "/api/\(rawValue)"
    }
}

class VersionedAPIClient: APIClientProtocol {
    private let version: APIVersion
    private let baseURL: URL
    
    init(baseURL: URL, version: APIVersion) {
        self.baseURL = baseURL
        self.version = version
    }
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        let versionedURL = baseURL.appendingPathComponent(version.basePath)
        let url = versionedURL.appendingPathComponent(endpoint.path)
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(version.rawValue, forHTTPHeaderField: "API-Version")
        
        // Continue with request implementation...
        fatalError("Implementation needed")
    }
}
```

## Network Monitoring

### DO: Network Status Monitoring
✅ **ALWAYS monitor network connectivity**

```swift
import Network

@Observable
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    
    var isConnected = false
    var connectionType: ConnectionType = .unknown
    var onNetworkStatusChange: ((Bool) -> Void)?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path: path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionStatus(path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        connectionType = determineConnectionType(path: path)
        
        if wasConnected != isConnected {
            onNetworkStatusChange?(isConnected)
        }
    }
    
    private func determineConnectionType(path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
}
```

## Rate Limiting

### DO: Rate Limiting Implementation
✅ **ALWAYS implement rate limiting for API calls**

```swift
class RateLimitedAPIClient: APIClientProtocol {
    private let apiClient: APIClient
    private let rateLimiter: RateLimiter
    
    init(apiClient: APIClient, rateLimiter: RateLimiter) {
        self.apiClient = apiClient
        self.rateLimiter = rateLimiter
    }
    
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        try await rateLimiter.waitForPermission()
        
        return try await apiClient.request(
            endpoint: endpoint,
            method: method,
            body: body
        )
    }
}

class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "rate.limiter")
    
    init(maxRequests: Int, timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func waitForPermission() async throws {
        await withCheckedContinuation { continuation in
            queue.async {
                self.cleanupOldRequests()
                
                if self.requestTimes.count >= self.maxRequests {
                    let oldestRequest = self.requestTimes.first!
                    let waitTime = self.timeWindow - Date().timeIntervalSince(oldestRequest)
                    
                    if waitTime > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                            self.requestTimes.append(Date())
                            continuation.resume()
                        }
                    } else {
                        self.requestTimes.append(Date())
                        continuation.resume()
                    }
                } else {
                    self.requestTimes.append(Date())
                    continuation.resume()
                }
            }
        }
    }
    
    private func cleanupOldRequests() {
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        requestTimes = requestTimes.filter { $0 > cutoffTime }
    }
}
```

## GraphQL Support

### DO: GraphQL Implementation
✅ **ALWAYS implement GraphQL support when needed**

```swift
class GraphQLClient {
    private let endpoint: URL
    private let session: URLSession
    
    init(endpoint: URL) {
        self.endpoint = endpoint
        self.session = URLSession.shared
    }
    
    func execute<T: Codable>(
        query: String,
        variables: [String: Any] = [:],
        operationName: String? = nil
    ) async throws -> GraphQLResponse<T> {
        let body = GraphQLRequest(
            query: query,
            variables: variables,
            operationName: operationName
        )
        
        let data = try JSONEncoder().encode(body)
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (responseData, _) = try await session.data(for: request)
        
        return try JSONDecoder().decode(GraphQLResponse<T>.self, from: responseData)
    }
}

struct GraphQLRequest: Codable {
    let query: String
    let variables: [String: Any]
    let operationName: String?
    
    enum CodingKeys: String, CodingKey {
        case query
        case variables
        case operationName
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(operationName, forKey: .operationName)
        
        // Handle variables dictionary encoding
        let variablesData = try JSONSerialization.data(withJSONObject: variables)
        let variablesJSON = try JSONSerialization.jsonObject(with: variablesData)
        try container.encode(variablesJSON as! [String: Any], forKey: .variables)
    }
}

struct GraphQLResponse<T: Codable>: Codable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Codable {
    let message: String
    let locations: [GraphQLLocation]?
    let path: [String]?
}

struct GraphQLLocation: Codable {
    let line: Int
    let column: Int
}
```

## Anti-Patterns to Avoid

### DON'T: Networking Mistakes
❌ **NEVER make synchronous network requests**
❌ **NEVER ignore error handling**
❌ **NEVER hardcode API endpoints**
❌ **NEVER skip request/response logging**
❌ **NEVER ignore rate limiting**
❌ **NEVER skip timeout configuration**

### DON'T: Common API Errors
❌ **NEVER expose sensitive data in URLs**
❌ **NEVER skip input validation**
❌ **NEVER ignore offline scenarios**
❌ **NEVER use global state for API responses**
❌ **NEVER skip authentication token refresh**
❌ **NEVER ignore network status changes**

## Best Practices Checklist

### DO: API Implementation Checklist
✅ **ALWAYS follow API best practices**

- [ ] Protocol-based API client design
- [ ] Comprehensive error handling
- [ ] Retry logic for transient failures
- [ ] Request/response interceptors
- [ ] Offline request queuing
- [ ] Intelligent response caching
- [ ] Mock implementations for testing
- [ ] API versioning support
- [ ] Network status monitoring
- [ ] Rate limiting implementation
- [ ] Proper authentication handling
- [ ] Input validation and sanitization
- [ ] Secure communication (HTTPS)
- [ ] Request/response logging
- [ ] Timeout configuration