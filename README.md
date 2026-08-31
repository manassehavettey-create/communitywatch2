# Community Watch - Ghana Safety App

A professional, real-time community safety application focused on the Ghanaian neighborhood landscape.

## Setup Instructions

### 1. Google Maps API Key
To use the map features, you must add your Google Maps API key to the following files:

**Android**: `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
               android:value="EyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjIzZmQ0MDA0ZWI2YTQzNTQ5N2YzMmU2ZjkwNzYwZDljIiwiaCI6Im11cm11cjY0In0="/>
```

**iOS**: `ios/Runner/AppDelegate.swift`
```swift
GMSServices.provideAPIKey("EyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjIzZmQ0MDA0ZWI2YTQzNTQ5N2YzMmU2ZjkwNzYwZDljIiwiaCI6Im11cm11cjY0In0=")
```

### 2. Permissions
The app requires location permissions to function. 
- The **Terms & Conditions** must be accepted before entry.
- **Location Services** must be enabled to view local incidents in Ghana.

## Core Features
- **3D Safety Feed**: Immersive incident reporting with perspective tilt.
- **Ghana Safety Map**: Real-time geolocation centered on Accra and regional Ghana.
- **Admin Console**: Professional moderation suite for user and report management.
- **Forced Compliance**: Ensures users agree to terms and enable location before access.
