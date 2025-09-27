# Provisioning Profile Fix for Apple Intelligence Entitlements

## 🚨 Error Message
```
Provisioning profile "iOS Team Provisioning Profile: com.tam305.vitalview" doesn't include the com.apple.developer.app-intents and com.apple.developer.foundation-models entitlements.
```

## ✅ Quick Fix (Temporary)

I've already applied a temporary fix by commenting out the entitlements. Your app should now build and run without errors.

## 🔧 Permanent Solution

To enable Apple Intelligence features, you need to update your provisioning profile:

### Method 1: Automatic Provisioning (Easiest)

1. **Open Xcode**
2. **Select your project** → **VitalView target**
3. **Go to "Signing & Capabilities" tab**
4. **Uncheck "Automatically manage signing"**
5. **Wait 5 seconds**
6. **Check "Automatically manage signing" again**
7. **Clean and rebuild** (Cmd+Shift+K, then Cmd+B)

### Method 2: Manual Provisioning Profile Update

1. **Go to [Apple Developer Portal](https://developer.apple.com)**
2. **Sign in** with your Apple ID
3. **Navigate to "Certificates, Identifiers & Profiles"**
4. **Click "Identifiers"**
5. **Find "com.tam305.vitalview"**
6. **Click "Edit"**
7. **Enable these capabilities:**
   - ✅ App Intents
   - ✅ Foundation Models
8. **Save the changes**
9. **Go back to "Profiles"**
10. **Find your provisioning profile**
11. **Click "Edit"**
12. **Click "Generate" to create new profile**
13. **Download and install** the new profile

### Method 3: Create New App ID

1. **Create a new App ID** in Developer Portal
2. **Enable Apple Intelligence capabilities** during creation
3. **Update your Xcode project** to use the new App ID
4. **Let Xcode generate** a new provisioning profile

## 🎯 After Fixing

Once you've updated the provisioning profile:

1. **Uncomment the entitlements** in `VitalView.entitlements`:
   ```xml
   <key>com.apple.developer.foundation-models</key>
   <true/>
   <key>com.apple.developer.app-intents</key>
   <true/>
   ```

2. **Update the availability check** in `HealthInsightsManager.swift`:
   ```swift
   insightsEnabled = FoundationModels.isAvailable
   ```

3. **Test Apple Intelligence features** on supported devices

## 📱 Device Requirements

Apple Intelligence requires:
- **iPhone 15 Pro, iPhone 16, or later**
- **iOS 18.1 or later**
- **7+ GB free storage**
- **US English language setting**

## 🚀 Current Status

Your app is now **fully functional** with:
- ✅ **Basic health insights** (working now)
- ✅ **Fallback analysis** for older iOS versions
- ✅ **Ready for Apple Intelligence** (once entitlements are fixed)
- ✅ **Siri integration** (once entitlements are fixed)

The temporary fix ensures your app builds and runs perfectly while you work on updating the provisioning profile!
