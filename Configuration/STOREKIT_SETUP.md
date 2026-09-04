# StoreKit Configuration Setup

## ✅ This App Loads Products from App Store Connect

**IMPORTANT**: This app is configured to load subscription products directly from App Store Connect, NOT from local StoreKit Configuration files.

### Current Implementation

The app uses StoreKit 2's `Product.products(for:)` API which automatically loads products from:
- ✅ **App Store Connect** (sandbox and production)
- ❌ **NOT** from local `.storekit` configuration files

### Code Location

See `SubscriptionManager.swift` - `loadProducts()` method:
```swift
let loadedProducts = try await Product.products(for: productIDs)
```

This API call loads products from App Store Connect based on:
- Bundle ID: `org.loveandchaos.theidealweek`
- Product IDs: `idealweekapp`, `idealweekappyearly`
- Signed-in Apple ID on the device

### StoreKit Configuration Schema Must Be Set to "None"

Even though the code loads from App Store Connect, you must ensure Xcode scheme settings don't override this:

#### How to Verify/Set StoreKit Configuration:

1. **Check Scheme Settings**:
   - Product → Scheme → Edit Scheme
   - Select "Run" in the left sidebar
   - Look for "StoreKit Configuration" option
   - **Ensure it's set to "None"** (not pointing to any `.storekit` file)

2. **Check for StoreKit Configuration Files**:
   - Look for any `.storekit` files in your project
   - If found, they should NOT be referenced in the scheme
   - Current status: ✅ No `.storekit` files found in this project

3. **Verify in Build Settings**:
   - Select your target (The Ideal Week)
   - Go to "Signing & Capabilities" tab
   - Ensure no StoreKit Configuration capability is added

### Why This Matters:

- ✅ **StoreKit Configuration files** (`.storekit`) are for local testing only
- ❌ They override real App Store Connect products when active in scheme
- ✅ Setting to "None" ensures the app uses real products from App Store Connect
- ✅ This is required for sandbox and production testing

### Current Subscription Configuration:

- **Subscription Group**: app fees
- **Subscription Group ID**: 21844932
- **Product IDs**:
  - `idealweekapp` (monthly subscription)
  - `idealweekappyearly` (yearly subscription)
- **Bundle ID**: `org.loveandchaos.theidealweek`

### Verification Steps:

1. ✅ **Code uses App Store Connect**: Already implemented
2. ✅ **No StoreKit config files**: Verified - none found
3. ⚠️ **Check Xcode scheme**: Ensure StoreKit Configuration is set to "None"
4. ⚠️ **Sandbox account**: Sign in with sandbox tester account in Settings > App Store
5. ⚠️ **Products in App Store Connect**: Verify products exist and are approved

### Troubleshooting:

If products don't load, check:

1. **StoreKit Configuration in Scheme**:
   - Product → Scheme → Edit Scheme → Run
   - StoreKit Configuration should be "None"

2. **Product Configuration in App Store Connect**:
   - Products must exist: `idealweekapp`, `idealweekappyearly`
   - Must be in subscription group "app fees" (ID: 21844932)
   - Must be associated with bundle ID: `org.loveandchaos.theidealweek`
   - Status must be "Ready to Submit" or "Approved"

3. **Sandbox Testing**:
   - Sign in with sandbox tester account in Settings > App Store
   - Products must be enabled for sandbox testing in App Store Connect

4. **Console Logs**:
   - Check console for detailed loading information
   - Logs will show if products loaded and from where
