# Request handling checks

Run the coordinator checks without a device, Firebase credentials, or network requests:

```sh
swiftc -parse-as-library documents/AIRequestCoordinator.swift Tests/AIRequestCoordinatorTests.swift -o /tmp/documents-ai-tests
/tmp/documents-ai-tests
```

These checks cover request spacing, serialized calls, quota cooldown and recovery, daily quota handling, bounded transient retries, authentication failures, offline errors, and cancellation.

Physical devices use App Attest in every build configuration. Simulator builds use App Check's debug provider; register their debug tokens in Firebase for local testing. Device builds require the App Attest production entitlement and the Apple team that owns the bundle identifier. Never commit debug tokens or signing credentials.
