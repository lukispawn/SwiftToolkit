# CI/CD and Automation Rules

## GitHub Actions Workflows

### DO: Comprehensive CI Pipeline
✅ **ALWAYS implement comprehensive CI workflows**

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

env:
  DEVELOPER_DIR: /Applications/Xcode_16.0.app/Contents/Developer

jobs:
  test:
    runs-on: macos-14
    strategy:
      matrix:
        destination: 
          - platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0
          - platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=17.0
          - platform=macOS,arch=arm64
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Select Xcode
      run: sudo xcode-select -s $DEVELOPER_DIR
    
    - name: Cache SPM Dependencies
      uses: actions/cache@v3
      with:
        path: |
          ~/Library/Developer/Xcode/DerivedData/**/SourcePackages
          ~/.cache/org.swift.swiftpm
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Install Dependencies
      run: xcodebuild -resolvePackageDependencies -scheme MyApp
    
    - name: Run Tests
      run: |
        xcodebuild test \
          -scheme MyApp \
          -destination "${{ matrix.destination }}" \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData
    
    - name: Generate Coverage Report
      run: |
        xcrun xccov view DerivedData/Logs/Test/*.xcresult --report --json > coverage.json
        
    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        file: coverage.json
        fail_ci_if_error: true

  lint:
    runs-on: macos-14
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Install SwiftLint
      run: brew install swiftlint
    
    - name: Run SwiftLint
      run: swiftlint lint --reporter github-actions-logging
    
    - name: Run SwiftFormat Check
      run: |
        brew install swiftformat
        swiftformat --lint Sources Tests

  security:
    runs-on: macos-14
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Security Scan
      run: |
        # Check for hardcoded secrets
        if grep -r "api_key\|password\|secret" Sources/ --include="*.swift"; then
          echo "Potential secrets found in source code"
          exit 1
        fi
    
    - name: Dependency Check
      run: |
        # Check for known vulnerabilities in dependencies
        swift package audit
```

### DO: Build and Archive Workflow
✅ **ALWAYS implement automated build and archive**

```yaml
# .github/workflows/build.yml
name: Build and Archive

on:
  push:
    tags: [ 'v*' ]

jobs:
  build:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_16.0.app/Contents/Developer
    
    - name: Import Code Signing Certificates
      env:
        P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
        KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
      run: |
        # Create keychain
        security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        security set-keychain-settings -lut 21600 build.keychain
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        
        # Import certificate
        echo "${{ secrets.CERTIFICATES_P12 }}" | base64 --decode > certificate.p12
        security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain
    
    - name: Install Provisioning Profile
      run: |
        mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
        echo "${{ secrets.PROVISIONING_PROFILE }}" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision
    
    - name: Build and Archive
      run: |
        xcodebuild archive \
          -scheme MyApp \
          -configuration Release \
          -destination generic/platform=iOS \
          -archivePath MyApp.xcarchive \
          CODE_SIGN_IDENTITY="${{ secrets.CODE_SIGN_IDENTITY }}" \
          PROVISIONING_PROFILE_SPECIFIER="${{ secrets.PROVISIONING_PROFILE_SPECIFIER }}"
    
    - name: Export IPA
      run: |
        xcodebuild -exportArchive \
          -archivePath MyApp.xcarchive \
          -exportPath export \
          -exportOptionsPlist ExportOptions.plist
    
    - name: Upload to TestFlight
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
      run: |
        xcrun altool --upload-app \
          --type ios \
          --file export/MyApp.ipa \
          --username "$APPLE_ID" \
          --password "$APPLE_PASSWORD"
```

## Fastlane Integration

### DO: Fastlane Configuration
✅ **ALWAYS implement Fastlane for deployment automation**

```ruby
# Fastfile
default_platform(:ios)

before_all do
  ensure_git_status_clean
  ensure_git_branch(branch: 'main')
end

platform :ios do
  desc "Run all tests"
  lane :test do
    run_tests(
      scheme: "MyApp",
      devices: ["iPhone 15 Pro", "iPad Pro (12.9-inch) (6th generation)"],
      code_coverage: true,
      output_directory: "test_output"
    )
  end

  desc "Build for development"
  lane :development do
    increment_build_number(
      build_number: latest_testflight_build_number + 1
    )
    
    build_app(
      scheme: "MyApp",
      configuration: "Debug",
      output_directory: "build"
    )
  end

  desc "Build and deploy to TestFlight"
  lane :beta do
    # Ensure we're on the right branch
    ensure_git_branch(branch: 'main')
    
    # Increment build number
    increment_build_number(
      build_number: latest_testflight_build_number + 1
    )
    
    # Build the app
    build_app(
      scheme: "MyApp",
      configuration: "Release",
      output_directory: "build"
    )
    
    # Upload to TestFlight
    upload_to_testflight(
      beta_app_feedback_email: "beta@example.com",
      beta_app_description: "Latest beta build",
      notify_external_testers: true,
      changelog: changelog_from_git_commits(
        between: [git_previous_tag, "HEAD"],
        pretty: "- %s"
      )
    )
    
    # Post to Slack
    slack(
      message: "New beta build uploaded to TestFlight! 🚀",
      channel: "#ios-releases"
    )
  end

  desc "Deploy to App Store"
  lane :release do
    # Ensure we're on the right branch
    ensure_git_branch(branch: 'main')
    
    # Increment version number
    increment_version_number(
      bump_type: "patch"
    )
    
    # Build the app
    build_app(
      scheme: "MyApp",
      configuration: "Release",
      output_directory: "build"
    )
    
    # Upload to App Store
    upload_to_app_store(
      force: true,
      reject_if_possible: true,
      skip_metadata: false,
      skip_screenshots: false,
      submit_for_review: true,
      automatic_release: false
    )
    
    # Create git tag
    add_git_tag(
      tag: "v#{get_version_number}",
      message: "Release v#{get_version_number}"
    )
    
    # Push to git
    push_to_git_remote(
      remote: "origin",
      local_branch: "main",
      remote_branch: "main",
      tags: true
    )
    
    # Post to Slack
    slack(
      message: "New release v#{get_version_number} submitted to App Store! 🎉",
      channel: "#ios-releases"
    )
  end

  desc "Run security audit"
  lane :security_audit do
    # Check for hardcoded secrets
    sh("grep -r 'api_key\\|password\\|secret' ../Sources/ --include='*.swift' && exit 1 || exit 0")
    
    # Check dependencies for vulnerabilities
    sh("swift package audit")
    
    # Run static analysis
    swiftlint(
      mode: :lint,
      reporter: "json",
      output_file: "swiftlint-report.json"
    )
  end

  error do |lane, exception|
    slack(
      message: "Lane #{lane} failed with error: #{exception.message}",
      channel: "#ios-releases",
      success: false
    )
  end
end
```

### DO: Fastlane Environment Configuration
✅ **ALWAYS configure Fastlane environment properly**

```ruby
# Appfile
app_identifier("com.example.myapp")
apple_id("developer@example.com")
itc_team_id("123456789")
team_id("ABCDEFGHIJ")

for_platform :ios do
  for_lane :beta do
    app_identifier("com.example.myapp.beta")
  end
end
```

## Code Quality Gates

### DO: Quality Gate Configuration
✅ **ALWAYS implement code quality gates**

```yaml
# .github/workflows/quality-gates.yml
name: Quality Gates

on:
  pull_request:
    branches: [ main, develop ]

jobs:
  quality-check:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Install Tools
      run: |
        brew install swiftlint swiftformat
        npm install -g danger
    
    - name: Code Style Check
      run: |
        swiftlint lint --reporter github-actions-logging
        swiftformat --lint Sources Tests
    
    - name: Run Danger
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: danger
    
    - name: Code Coverage Check
      run: |
        xcodebuild test \
          -scheme MyApp \
          -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData
        
        # Extract coverage percentage
        COVERAGE=$(xcrun xccov view DerivedData/Logs/Test/*.xcresult --report --json | jq '.lineCoverage')
        echo "Coverage: $COVERAGE%"
        
        # Fail if coverage is below threshold
        if (( $(echo "$COVERAGE < 80" | bc -l) )); then
          echo "Coverage $COVERAGE% is below threshold of 80%"
          exit 1
        fi
    
    - name: Security Check
      run: |
        # Check for common security issues
        if grep -r "NSAllowsArbitraryLoads.*true" .; then
          echo "Found NSAllowsArbitraryLoads set to true"
          exit 1
        fi
        
        # Check for hardcoded secrets
        if grep -r "api_key\|password\|secret" Sources/ --include="*.swift"; then
          echo "Potential secrets found in source code"
          exit 1
        fi
```

## Dependency Management

### DO: Dependency Security Scanning
✅ **ALWAYS scan dependencies for vulnerabilities**

```yaml
# .github/workflows/dependency-check.yml
name: Dependency Security Check

on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday
  push:
    paths:
      - 'Package.swift'
      - 'Package.resolved'

jobs:
  dependency-check:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Swift Package Audit
      run: |
        swift package audit
        
    - name: Check for Outdated Dependencies
      run: |
        swift package show-dependencies --format json > dependencies.json
        
        # Parse and check for outdated packages
        # This would typically integrate with a service like Snyk or similar
        
    - name: Generate Dependency Report
      run: |
        swift package show-dependencies > dependency-report.txt
        
    - name: Upload Dependency Report
      uses: actions/upload-artifact@v3
      with:
        name: dependency-report
        path: dependency-report.txt
```

## Build Configuration Management

### DO: Build Configuration
✅ **ALWAYS manage build configurations properly**

```swift
// BuildConfiguration.swift
import Foundation

enum BuildConfiguration {
    case debug
    case release
    case testing
    
    static var current: BuildConfiguration {
        #if DEBUG
        return .debug
        #elseif TESTING
        return .testing
        #else
        return .release
        #endif
    }
    
    var baseURL: String {
        switch self {
        case .debug:
            return "https://api-dev.example.com"
        case .testing:
            return "https://api-staging.example.com"
        case .release:
            return "https://api.example.com"
        }
    }
    
    var logLevel: LogLevel {
        switch self {
        case .debug:
            return .debug
        case .testing:
            return .info
        case .release:
            return .error
        }
    }
    
    var enableAnalytics: Bool {
        switch self {
        case .debug, .testing:
            return false
        case .release:
            return true
        }
    }
}

// Usage in Info.plist
/*
<key>BaseURL</key>
<string>$(BASE_URL)</string>
<key>LogLevel</key>
<string>$(LOG_LEVEL)</string>
*/
```

## Release Automation

### DO: Automated Release Process
✅ **ALWAYS automate the release process**

```bash
#!/bin/bash
# release.sh

set -e

# Configuration
SCHEME="MyApp"
CONFIGURATION="Release"
WORKSPACE="MyApp.xcworkspace"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're on the main branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    log_error "Please switch to main branch before creating a release"
    exit 1
fi

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    log_error "Working directory is not clean. Please commit or stash changes."
    exit 1
fi

# Get version from user
read -p "Enter version number (e.g., 1.2.3): " VERSION

if [ -z "$VERSION" ]; then
    log_error "Version number is required"
    exit 1
fi

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format. Use semantic versioning (e.g., 1.2.3)"
    exit 1
fi

log_info "Creating release for version $VERSION"

# Update version in project
agvtool new-marketing-version $VERSION

# Commit version change
git add .
git commit -m "Bump version to $VERSION"

# Create git tag
git tag -a "v$VERSION" -m "Release v$VERSION"

# Push changes and tags
git push origin main
git push origin "v$VERSION"

# Trigger release workflow
gh workflow run build.yml

log_info "Release v$VERSION created successfully!"
log_info "Check GitHub Actions for build status"
```

## Automated Testing

### DO: Comprehensive Test Automation
✅ **ALWAYS implement comprehensive test automation**

```yaml
# .github/workflows/test-automation.yml
name: Test Automation

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  unit-tests:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -scheme MyApp \
          -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData
    
    - name: Generate Test Report
      run: |
        xcrun xccov view DerivedData/Logs/Test/*.xcresult --report --json > test-report.json
        
    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: test-report.json

  ui-tests:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Run UI Tests
      run: |
        xcodebuild test \
          -scheme MyAppUITests \
          -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
          -derivedDataPath DerivedData
    
    - name: Upload UI Test Screenshots
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: ui-test-screenshots
        path: DerivedData/Logs/Test/Attachments

  performance-tests:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Run Performance Tests
      run: |
        xcodebuild test \
          -scheme MyAppPerformanceTests \
          -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
          -derivedDataPath DerivedData
    
    - name: Analyze Performance Results
      run: |
        # Extract performance metrics
        xcrun xcresulttool get --path DerivedData/Logs/Test/*.xcresult --format json > performance-results.json
        
    - name: Upload Performance Results
      uses: actions/upload-artifact@v3
      with:
        name: performance-results
        path: performance-results.json
```

## Code Signing Automation

### DO: Automated Code Signing
✅ **ALWAYS automate code signing process**

```bash
#!/bin/bash
# setup-code-signing.sh

set -e

# Configuration
KEYCHAIN_NAME="build.keychain"
KEYCHAIN_PASSWORD="$1"
CERTIFICATE_PATH="$2"
CERTIFICATE_PASSWORD="$3"
PROVISIONING_PROFILE_PATH="$4"

# Create keychain
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Import certificate
security import "$CERTIFICATE_PATH" -k "$KEYCHAIN_NAME" -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Install provisioning profile
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp "$PROVISIONING_PROFILE_PATH" ~/Library/MobileDevice/Provisioning\ Profiles/

# List available code signing identities
security find-identity -v -p codesigning "$KEYCHAIN_NAME"

# List installed provisioning profiles
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/
```

## Deployment Automation

### DO: Automated Deployment Pipeline
✅ **ALWAYS implement automated deployment**

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  release:
    types: [published]

jobs:
  deploy-beta:
    runs-on: macos-14
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.0
        bundler-cache: true
    
    - name: Deploy to TestFlight
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
        FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
      run: |
        bundle exec fastlane beta

  deploy-production:
    runs-on: macos-14
    if: github.event.release.prerelease == false
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
    
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.0
        bundler-cache: true
    
    - name: Deploy to App Store
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
        FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
      run: |
        bundle exec fastlane release

  notify:
    runs-on: ubuntu-latest
    needs: [deploy-beta, deploy-production]
    if: always()
    
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#ios-releases'
        text: 'Deployment completed'
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Anti-Patterns to Avoid

### DON'T: CI/CD Mistakes
❌ **NEVER skip automated testing in CI pipeline**
❌ **NEVER store secrets in code or version control**
❌ **NEVER deploy without proper code signing**
❌ **NEVER skip security scanning**
❌ **NEVER ignore build warnings**
❌ **NEVER deploy untested code**

### DON'T: Common Automation Errors
❌ **NEVER hardcode environment-specific values**
❌ **NEVER skip dependency vulnerability scanning**
❌ **NEVER ignore code quality gates**
❌ **NEVER skip automated backups**
❌ **NEVER deploy without proper monitoring**

## CI/CD Best Practices Checklist

### DO: CI/CD Implementation Checklist
✅ **ALWAYS follow CI/CD best practices**

- [ ] Comprehensive test suite running on all PRs
- [ ] Automated code quality checks (linting, formatting)
- [ ] Security scanning for vulnerabilities
- [ ] Automated dependency updates
- [ ] Proper secrets management
- [ ] Automated code signing
- [ ] Staged deployment process (beta → production)
- [ ] Automated rollback capabilities
- [ ] Monitoring and alerting
- [ ] Documentation for all workflows
- [ ] Regular pipeline maintenance
- [ ] Performance monitoring
- [ ] Automated changelog generation
- [ ] Notification system for failures
- [ ] Artifact management and cleanup