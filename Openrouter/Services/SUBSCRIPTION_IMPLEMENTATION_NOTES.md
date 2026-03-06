//
//  SUBSCRIPTION_IMPLEMENTATION_NOTES.md
//  OpenRouter App
//
//  Comprehensive guide for subscription implementation
//

# Subscription Implementation Guide

## Architecture Overview

### SubscriptionManager (Singleton, MainActor)
The central coordinator for all subscription-related operations:

```swift
- Manages StoreKit 2 product loading
- Handles purchase transactions
- Monitors subscription status changes
- Provides transaction listener for background updates
- Synchronizes with UserPreferences
```

**Key Features:**
- **Thread Safety:** All operations run on MainActor
- **State Management:** Published properties for SwiftUI observation
- **Error Handling:** Comprehensive error types with recovery suggestions
- **Logging:** OSLog integration for debugging

### State Flow

```
App Launch
    ↓
SubscriptionManager.init()
    ↓
Load Products from App Store
    ↓
Check Current Subscription Status
    ↓
Update isSubscribed & subscriptionStatus
    ↓
Notify UserPreferences (if changed)
    ↓
UI Updates Automatically
```

### Transaction Verification

All transactions are verified using StoreKit 2's built-in verification:

```swift
switch verificationResult {
case .verified(let transaction):
    // Safe to use - cryptographically verified by App Store
    return transaction
case .unverified(_, let error):
    // Potential tampering - reject transaction
    throw SubscriptionError.failedVerification
}
```

## Subscription States Explained

### 1. `.notSubscribed`
- **User Impact:** No premium features
- **UI:** Show upgrade prompts
- **Action:** Encourage subscription

### 2. `.subscribed(expirationDate)`
- **User Impact:** Full premium access
- **UI:** Show "Active" badge with renewal date
- **Action:** None required

### 3. `.inGracePeriod(expirationDate)`
- **User Impact:** Maintains premium access
- **Reason:** Payment failed, Apple is retrying
- **UI:** Show warning to update payment method
- **Action:** Prompt user to fix payment issue

### 4. `.inBillingRetryPeriod(expirationDate)`
- **User Impact:** Maintains premium access
- **Reason:** Apple is actively retrying payment
- **UI:** Show notification about retry
- **Action:** Suggest updating payment method in Settings

### 5. `.expired(expirationDate)`
- **User Impact:** Premium features locked
- **Reason:** Subscription ended (not renewed)
- **UI:** Show expiration date
- **Action:** Encourage re-subscription

### 6. `.revoked`
- **User Impact:** Premium features locked
- **Reason:** Refund issued or other issue
- **UI:** Show revoked status
- **Action:** Contact support or re-subscribe

### 7. `.unknown`
- **User Impact:** Premium features locked (fail-safe)
- **Reason:** Unable to determine status
- **UI:** Show error state
- **Action:** Retry status check

## Best Practices Implemented

### 1. Transaction Listener
Runs in background to catch subscription changes:
- Renewals
- Expirations
- Cancellations
- Refunds

### 2. Grace Period Support
Maintains user access during payment issues:
- Better user experience
- Higher retention rates
- Follows Apple recommendations

### 3. Family Sharing Detection
```swift
let isShared = await subscriptionManager.isSubscriptionShared()
```

### 4. Modern StoreKit APIs
Uses latest StoreKit 2 features:
- `Transaction.currentEntitlements(for:)` - iOS 18.4+
- Async/await throughout
- Structured concurrency

### 5. Error Recovery
All errors include:
- Clear descriptions
- Recovery suggestions
- Appropriate logging level

## Testing Strategy

### Sandbox Testing

1. **Create Test Accounts**
   - Settings > App Store Connect > Sandbox
   - Create accounts for different scenarios

2. **Test Subscription Durations**
   - Sandbox accelerates time:
     - 1 week subscription = 3 minutes
     - 1 month subscription = 5 minutes
     - 2 months subscription = 10 minutes
     - 3 months subscription = 15 minutes
     - 6 months subscription = 30 minutes
     - 1 year subscription = 1 hour

3. **Test Scenarios**
   - Purchase monthly subscription
   - Purchase yearly subscription
   - Cancel and restore
   - Let subscription expire
   - Test grace period (payment failure)
   - Test billing retry
   - Test refund (revoked state)

### StoreKit Configuration File

Create local configuration for offline testing:

```
File > New > File
Search: "StoreKit Configuration File"
Add: Monthly and yearly subscription products
```

### Production Testing Checklist

- [ ] Real App Store Connect products
- [ ] TestFlight beta testing
- [ ] Different regions/currencies
- [ ] Family Sharing (if enabled)
- [ ] Edge cases (airplane mode, etc.)

## Privacy & Security

### Privacy Manifest (PrivacyInfo.xcprivacy)
Declares:
- No tracking
- Purchase history collection (for app functionality)
- UserDefaults usage
- File timestamp access

### Keychain Integration
- API keys stored securely
- Never logged or exposed
- Proper error handling

### Data Collection
Minimal data collection:
- Subscription status (local only)
- Purchase history (for restoration)
- User preferences (CloudKit sync)

## Common Issues & Solutions

### Issue: Products Not Loading
**Symptoms:** Empty product list
**Causes:**
- Product IDs mismatch
- No internet connection
- App Store Connect configuration incomplete

**Solution:**
```swift
// Verify product IDs match exactly
logger.error("Failed to load products - check product IDs and App Store Connect configuration")
```

### Issue: Restore Doesn't Find Purchases
**Symptoms:** "No previous purchases found"
**Causes:**
- Different Apple ID
- Subscription expired
- Never purchased

**Solution:**
- Verify sandbox account
- Check transaction history
- Try AppStore.sync()

### Issue: Subscription Status Not Updating
**Symptoms:** UI shows wrong status
**Causes:**
- Transaction listener not running
- Network issue
- App in background

**Solution:**
- Call checkSubscriptionStatus() on appear
- Verify transaction listener is active
- Check network connectivity

## Performance Considerations

### Product Loading
- Cached after initial load
- Async operation
- Shows loading state

### Status Checks
- Efficient with currentEntitlements(for:)
- Only checks relevant products
- Cached in memory

### Transaction Listener
- Background priority
- Minimal resource usage
- Automatic cleanup on deinit

## Future Enhancements

### Potential Additions

1. **Promotional Offers**
```swift
// Win-back offers for lapsed subscribers
if subscriptionStatus == .expired {
    // Show special offer
}
```

2. **Introductory Pricing**
```swift
if let intro = product.subscription?.introductoryOffer {
    // Display intro pricing
}
```

3. **Analytics Integration**
```swift
// Track subscription events
Analytics.log("subscription_started", parameters: ["plan": "monthly"])
```

4. **A/B Testing**
```swift
// Test different pricing or UI
if userSegment == .groupA {
    // Show variant A
}
```

5. **Customer Support Integration**
```swift
// Easy access to support for subscription issues
Button("Contact Support") {
    // Open support channel
}
```

## App Store Connect Configuration

### Subscription Group Setup

1. **Create Subscription Group**
   - Name: "Premium Subscriptions"
   - ID: `premium_subscriptions`

2. **Add Monthly Product**
   - Product ID: `com.openrouter.premium.monthly`
   - Reference Name: "Premium Monthly"
   - Duration: 1 month
   - Price: Set per region

3. **Add Yearly Product**
   - Product ID: `com.openrouter.premium.yearly`
   - Reference Name: "Premium Yearly"
   - Duration: 1 year
   - Price: Set per region (typically 20-30% savings)

4. **Localization**
   - Add display names for all supported languages
   - Include clear subscription descriptions
   - Mention auto-renewal terms

5. **Review Information**
   - Screenshot showing subscription UI
   - Review notes explaining features
   - Demo account if features are gated

## Legal Requirements

### Auto-Renewal Disclosure
Must clearly state:
- Payment charged to Apple ID at confirmation
- Auto-renewal unless cancelled
- Where to manage subscriptions
- Cancellation takes effect after current period

### Terms Implementation
```swift
// In SubscriptionView
Text("Subscription automatically renews unless cancelled 24 hours before the end of the current period.")
    .font(.caption2)
    .foregroundColor(.secondary)
```

## Monitoring & Maintenance

### Metrics to Monitor

1. **Conversion Rate**
   - Views of subscription screen
   - Purchase attempts
   - Successful purchases

2. **Retention**
   - Active subscriptions
   - Churn rate
   - Grace period recovery

3. **Revenue**
   - Monthly recurring revenue (MRR)
   - Average revenue per user (ARPU)
   - Lifetime value (LTV)

### Logging Best Practices

```swift
// Use appropriate log levels
logger.info("Normal operations")
logger.notice("Important events")
logger.warning("Concerning but not critical")
logger.error("Errors requiring attention")
```

### Health Checks

Regular verification:
- [ ] Products loading correctly
- [ ] Transaction listener active
- [ ] Status checks accurate
- [ ] UI updates responsive
- [ ] Error handling working

## Support Resources

### Apple Documentation
- [StoreKit 2](https://developer.apple.com/documentation/storekit)
- [In-App Purchase](https://developer.apple.com/in-app-purchase/)
- [Subscription Best Practices](https://developer.apple.com/app-store/subscriptions/)

### Sample Code
- [Implementing In-App Purchase](https://developer.apple.com/documentation/storekit/in-app_purchase/implementing_a_store_in_your_app_using_the_storekit_api)
- [Managing Subscriptions](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/subscriptions_and_offers)

### Tools
- Xcode StoreKit testing
- Transaction Manager
- App Store Connect
- TestFlight

---

**Implementation Date:** January 26, 2026
**Last Updated:** February 2, 2026
**Framework:** StoreKit 2
**Minimum Deployment:** iOS 17.0+, macOS 14.0+
