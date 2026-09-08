import Foundation

@MainActor
final class TestClock {
  var date = Date(timeIntervalSince1970: 1_000)
  var waits: [TimeInterval] = []

  func sleep(_ seconds: TimeInterval) async throws {
    waits.append(seconds)
    date = date.addingTimeInterval(seconds)
    await Task.yield()
  }
}

@main
struct AIRequestCoordinatorTests {
  @MainActor
  static func main() async throws {
    let clock = TestClock()
    let coordinator = AIRequestCoordinator(now: { clock.date }, sleep: clock.sleep)
    var starts: [Date] = []
    for _ in 0..<3 {
      let value = try await coordinator.perform {
        starts.append(clock.date)
        return 42
      }
      precondition(value == 42)
    }
    precondition(starts[1].timeIntervalSince(starts[0]) >= 7)
    precondition(starts[2].timeIntervalSince(starts[1]) >= 7)

    let quotaClock = TestClock()
    let quota = AIRequestCoordinator(now: { quotaClock.date }, sleep: quotaClock.sleep)
    var quotaAttempts = 0
    for _ in 0..<3 {
      do {
        _ = try await quota.perform {
          quotaAttempts += 1
          throw NSError(
            domain: "HTTP", code: 429,
            userInfo: [NSLocalizedDescriptionKey: "RESOURCE_EXHAUSTED: Please retry in 90s."])
        }
        preconditionFailure("Quota errors must reach the caller")
      } catch AIRequestFailure.rateLimited(let date) {
        precondition(date == Date(timeIntervalSince1970: 1_090))
      }
    }
    precondition(quotaAttempts == 1)
    quotaClock.date = Date(timeIntervalSince1970: 1_090)
    _ = try await quota.perform { quotaAttempts += 1 }
    precondition(quotaAttempts == 2)

    let dailyClock = TestClock()
    let daily = AIRequestCoordinator(now: { dailyClock.date }, sleep: dailyClock.sleep)
    var dailyAttempts = 0
    for _ in 0..<2 {
      do {
        _ = try await daily.perform {
          dailyAttempts += 1
          throw NSError(
            domain: "HTTP", code: 429,
            userInfo: [
              NSLocalizedDescriptionKey: "RESOURCE_EXHAUSTED GenerateRequestsPerDayPerProject"
            ])
        }
        preconditionFailure("Daily quota must stop requests")
      } catch AIRequestFailure.dailyQuota {}
    }
    precondition(dailyAttempts == 1)

    let retryClock = TestClock()
    let transient = AIRequestCoordinator(now: { retryClock.date }, sleep: retryClock.sleep)
    var attempts = 0
    let recovered = try await transient.perform {
      attempts += 1
      if attempts < 3 {
        throw NSError(
          domain: "HTTP", code: 503, userInfo: [NSLocalizedDescriptionKey: "503 UNAVAILABLE"])
      }
      return "recovered"
    }
    precondition(recovered == "recovered" && attempts == 3)
    attempts = 0
    do {
      _ = try await transient.perform {
        attempts += 1
        throw NSError(
          domain: "HTTP", code: 503, userInfo: [NSLocalizedDescriptionKey: "503 UNAVAILABLE"])
      }
      preconditionFailure("Retries must be bounded")
    } catch AIRequestFailure.temporary {}
    precondition(attempts == 3)

    let denied = AIRequestCoordinator(minimumInterval: 0)
    var deniedAttempts = 0
    do {
      _ = try await denied.perform {
        deniedAttempts += 1
        throw NSError(
          domain: "HTTP", code: 403,
          userInfo: [NSLocalizedDescriptionKey: "PERMISSION_DENIED: invalid App Check token"])
      }
      preconditionFailure("Access errors must reach the caller")
    } catch AIRequestFailure.accessDenied {}
    precondition(deniedAttempts == 1)

    let offline = AIRequestFailure.classify(URLError(.notConnectedToInternet), now: clock.date)
    guard case .offline = offline else { preconditionFailure("Offline must be actionable") }
    precondition(AIRequestFailure.retryDelay(in: #"retrydelay: \"12.5s\""#) == nil)
    precondition(AIRequestFailure.retryDelay(in: "retry-after: 120") == 120)
    precondition(AIRequestFailure.retryDelay(in: "retrydelay: 12.5s") == 12.5)

    let serialClock = TestClock()
    let serial = AIRequestCoordinator(
      minimumInterval: 0, now: { serialClock.date }, sleep: serialClock.sleep)
    var concurrent = 0
    var maximumConcurrent = 0
    let first = Task { @MainActor in
      try await serial.perform {
        concurrent += 1
        maximumConcurrent = max(maximumConcurrent, concurrent)
        for _ in 0..<10 { await Task.yield() }
        concurrent -= 1
      }
    }
    let second = Task { @MainActor in
      try await serial.perform {
        concurrent += 1
        maximumConcurrent = max(maximumConcurrent, concurrent)
        concurrent -= 1
      }
    }
    try await first.value
    try await second.value
    precondition(maximumConcurrent == 1)

    let cancelled = Task { @MainActor in
      try await serial.perform { () -> Void in
        preconditionFailure("Cancelled work cannot make a request")
      }
    }
    cancelled.cancel()
    do {
      _ = try await cancelled.value
      preconditionFailure("Cancellation must propagate")
    } catch is CancellationError {}
    print(
      "PASS: pacing, quota cooldown and resume, daily quota, bounded retries, access errors, offline errors, serialization, cancellation"
    )
  }
}
