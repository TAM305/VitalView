# Apple Intelligence Xcode Setup Guide for VitalView

This guide will help you properly configure your VitalView project to use Apple Intelligence frameworks in Xcode 26+.

## Prerequisites

- **Xcode 26 or later**
- **Target iOS 18.1 or later** (for iPhone 15 Pro, iPhone 16, or later)
- **Device Requirements**: iPhone 15 Pro, iPhone 16, or later with M1 chip or later
- **Minimum Storage**: 7 GB free space on target device
- **Language**: Device and Siri language set to supported language (e.g., US English)

## Step 1: Add Required Frameworks

### 1.1 Open Your Xcode Project
1. Open `VitalVu.xcodeproj` in Xcode 26+
2. Select your project in the Project Navigator
3. Select the **VitalView** target

### 1.2 Add FoundationModels Framework
1. Go to **General** tab
2. Scroll down to **Frameworks, Libraries, and Embedded Content**
3. Click the **+** button
4. Search for **FoundationModels**
5. Select **FoundationModels.framework**
6. Click **Add**

### 1.3 Add App Intents Framework
1. In the same **Frameworks, Libraries, and Embedded Content** section
2. Click the **+** button again
3. Search for **AppIntents**
4. Select **AppIntents.framework**
5. Click **Add**

### 1.4 Add VisualIntelligence Framework (Optional)
1. Click the **+** button again
2. Search for **VisualIntelligence**
3. Select **VisualIntelligence.framework**
4. Click **Add**

## Step 2: Configure Build Settings

### 2.1 Update Deployment Target
1. Go to **Build Settings** tab
2. Search for **iOS Deployment Target**
3. Set it to **18.1** or later

### 2.2 Update SDK
1. In **Build Settings**
2. Search for **iOS SDK**
3. Ensure it's set to the latest available SDK

## Step 3: Configure Signing & Capabilities

### 3.1 Add Apple Intelligence Capabilities
1. Go to **Signing & Capabilities** tab
2. Click **+ Capability**
3. Search for **Foundation Models**
4. Add the capability
5. Click **+ Capability** again
6. Search for **App Intents**
7. Add the capability

### 3.2 Verify Entitlements
Your `VitalView.entitlements` file should now include:
```xml
<key>com.apple.developer.foundation-models</key>
<true/>
<key>com.apple.developer.app-intents</key>
<true/>
```

## Step 4: Update Info.plist

Your `Info.plist` should include these usage descriptions:
```xml
<key>NSFoundationModelsUsageDescription</key>
<string>VitalView uses Foundation Models to provide AI-powered health insights and recommendations based on your blood test results and vital signs. All analysis is performed on-device to protect your privacy.</string>

<key>NSAppIntentsUsageDescription</key>
<string>VitalView uses App Intents to allow Siri and Apple Intelligence to access your health insights and provide voice-activated health analysis.</string>
```

## Step 5: Code Integration

### 5.1 Import Statements
Your Swift files should include:
```swift
import FoundationModels
import AppIntents
```

### 5.2 Availability Checks
Always check for availability:
```swift
if #available(iOS 18.1, *) {
    // Use FoundationModels and App Intents
} else {
    // Fallback to basic functionality
}
```

## Step 6: Testing

### 6.1 Device Requirements
- Test on iPhone 15 Pro, iPhone 16, or later
- Ensure device has iOS 18.1 or later
- Verify 7+ GB free storage
- Set device language to US English

### 6.2 Siri Integration
1. Test App Intents with Siri
2. Try commands like:
   - "Hey Siri, get my health insights in VitalView"
   - "Hey Siri, analyze my blood test in VitalView"
   - "Hey Siri, what's my health summary in VitalView"

## Step 7: Troubleshooting

### Common Issues:

1. **"FoundationModels not available"**
   - Check device compatibility (iPhone 15 Pro+)
   - Verify iOS 18.1+ is installed
   - Ensure 7+ GB free storage

2. **"App Intents not working"**
   - Check entitlements are properly configured
   - Verify Siri language is set to supported language
   - Test on physical device (not simulator)

3. **Build errors**
   - Ensure Xcode 26+ is being used
   - Check deployment target is 18.1+
   - Verify all frameworks are properly linked

### Debug Steps:
1. Check `FoundationModels.isAvailable` in your code
2. Verify entitlements in device settings
3. Test App Intents in Siri settings
4. Check device logs for errors

## Step 8: App Store Submission

### 8.1 Prerequisites
- Ensure all Apple Intelligence features work on supported devices
- Test thoroughly on iPhone 15 Pro/16+
- Verify privacy compliance

### 8.2 App Store Connect
- Mark your app as using Apple Intelligence
- Provide clear descriptions of AI features
- Ensure compliance with Apple Intelligence guidelines

## Files Modified

The following files have been updated for Apple Intelligence integration:

1. **VitalView/Models/HealthInsightsManager.swift**
   - Added FoundationModels import
   - Updated to use FoundationModels for AI analysis
   - Added fallback for older iOS versions

2. **VitalView/Models/HealthAppIntents.swift** (New)
   - Created App Intents for Siri integration
   - Defined health insight intents
   - Added result types and queries

3. **VitalView.entitlements**
   - Added FoundationModels entitlement
   - Added App Intents entitlement

4. **Info.plist**
   - Added FoundationModels usage description
   - Added App Intents usage description

## Next Steps

1. **Add frameworks to Xcode project** (Steps 1-2)
2. **Configure capabilities** (Step 3)
3. **Test on supported device** (Step 6)
4. **Submit to App Store** (Step 8)

Your VitalView app is now ready for Apple Intelligence integration! 🚀
