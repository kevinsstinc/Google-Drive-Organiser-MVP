# Request handling checks

Run the coordinator checks without a device, Firebase credentials, or network requests:

```sh
swiftc -parse-as-library documents/AIRequestCoordinator.swift Tests/AIRequestCoordinatorTests.swift -o /tmp/documents-ai-tests
/tmp/documents-ai-tests
```

These checks cover request spacing, serialized calls, quota cooldown and recovery, daily quota handling, bounded transient retries, authentication failures, offline errors, and cancellation.

Device builds use App Check's debug provider in Debug and App Attest in Release. Register the device's debug token in Firebase for local testing. Release builds require the App Attest production entitlement and the Apple team that owns the bundle identifier. Never commit debug tokens or signing credentials.
