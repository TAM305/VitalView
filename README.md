A comprehensive health monitoring application that integrates with HealthKit to track and analyze blood work results and vital signs.

## Overview

VitalView is a sophisticated iOS application designed to help users monitor their health by tracking blood test results, vital signs, and other health metrics. The app seamlessly integrates with Apple Health to provide a comprehensive view of your health data while maintaining privacy and security.

## Topics

### Core Application

- ``ContentView``
- ``PersistenceController``

### Data Models

- ``BloodTest``
- ``TestResult``
- ``BloodTestViewModel``

### Health Integration

- ``HealthMetricsView``

### User Interface

- ``AddTestView``
- ``TestResultView``
- ``SettingsView``
- ``PrivacyView``
- ``ExplanationView``
- ``BloodDropView``

## Features

### HealthKit Integration

VitalView seamlessly connects with Apple Health to read and analyze your vital signs including:

- Heart rate and heart rate variability
- Blood pressure (systolic and diastolic)
- Oxygen saturation
- Body temperature
- Respiratory rate
- Electrocardiogram data

### Blood Test Tracking

The app allows you to manually enter and track blood test results with:

- Complete Blood Count (CBC) analysis
- Comprehensive Metabolic Panel (CMP) tracking
- Custom test result entry
- Inline child‑friendly explanations for each analyte (tap the info icon)
- Reference ranges shown next to each field with real‑time HIGH/LOW/NORMAL status
- Trend analysis over time in a dedicated Trends tab

### Privacy and Security

Your health data is protected with:

- Local data storage with optional HealthKit synchronization
- Biometric authentication (Face ID/Touch ID)
- Secure data encryption
- Privacy-first design principles

### Data Analysis

VitalView provides intelligent analysis of your health data:

- Automatic status determination (normal, high, low) with robust range parsing (units, <, >)
- Trend visualization for Health metrics and Blood tests (separate views)
- Reference range validation (non‑blocking; out‑of‑range values still save)
- Detailed explanations of test results; educational summaries for blood tests

### Navigation & UX

- Tab‑based navigation for clarity:
  - Dashboard tab (vital signs, HealthKit)
  - Trends tab (segmented: Health Trends, Blood Test Trends)
- Floating “+” button on Dashboard to add a blood test
- Reduced bottom clutter per Apple HIG; moved secondary actions to Trends tab

### Data Export/Import

- Export to JSON with improved error handling and pretty‑printed format
- Share via the system share sheet when encoding succeeds
- Import supports security‑scoped bookmarks

## Getting Started

1. **Install the App**: Download VitalView from the App Store
2. **Grant Permissions**: Allow access to HealthKit data when prompted
3. **Add Blood Tests**: Tap the “+” button on Dashboard to enter results (see normal ranges and explanations)
4. **Monitor Trends**: Open the Trends tab; select Health or Blood, then pick time range and analyte
5. **Stay Informed**: Receive insights about your health metrics

## Privacy

VitalView is designed with privacy in mind. Your health data is stored locally on your device and is only shared with Apple Health if you explicitly choose to do so. The app uses biometric authentication to ensure only you can access your sensitive health information.

## Support

For support and questions about VitalView, please contact our development team through the app's settings or visit our support website.

---

**Version**: 1.0  
**Platform**: iOS 18.4+  
**Copyright**: © 2025 VitalView. All rights reserved. 
