import Foundation

@MainActor
final class AIRequestCoordinator {
  private let minimumInterval: TimeInterval
  private let now: () -> Date
  private let sleep: (TimeInterval) async throws -> Void
  private var nextRequestAt = Date.distantPast
  private(set) var retryAt: Date?
  private var blockedFailure: AIRequestFailure?
  private var requestInFlight = false

  init(
    minimumInterval: TimeInterval = 7,
    now: @escaping () -> Date = Date.init,
    sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
      try await Task.sleep(for: .seconds(seconds))
    }
  ) {
    self.minimumInterval = minimumInterval
    self.now = now
    self.sleep = sleep
  }

  func perform<Value>(_ request: () async throws -> Value) async throws -> Value {
    while requestInFlight {
      try await sleep(0.1)
      try Task.checkCancellation()
    }
    requestInFlight = true
    defer { requestInFlight = false }
    if let retryAt, retryAt > now(), let blockedFailure {
      throw blockedFailure
    }
    retryAt = nil
    blockedFailure = nil

    for attempt in 0..<3 {
      try Task.checkCancellation()
      let delay = nextRequestAt.timeIntervalSince(now())
      if delay > 0 {
        try await sleep(delay)
      }
      try Task.checkCancellation()
      nextRequestAt = now().addingTimeInterval(minimumInterval)

      do {
        return try await request()
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        let failure = AIRequestFailure.classify(error, now: now())
        if case .rateLimited(let date) = failure {
          retryAt = date
          blockedFailure = failure
          throw failure
        }
        if case .dailyQuota = failure {
          retryAt = now().addingTimeInterval(3_600)
          blockedFailure = failure
          throw failure
        }
        guard case .temporary = failure, attempt < 2 else {
          throw failure
        }
        nextRequestAt = max(nextRequestAt, now().addingTimeInterval(pow(2, Double(attempt + 1))))
      }
    }
    throw AIRequestFailure.temporary
  }
}

enum AIRequestFailure: Error, LocalizedError {
  case rateLimited(retryAt: Date)
  case dailyQuota
  case accessDenied
  case configuration
  case offline
  case temporary
  case invalidResponse
  case other

  var errorDescription: String? {
    switch self {
    case .rateLimited(let retryAt):
      let time = retryAt.formatted(date: .omitted, time: .shortened)
      return "AI is temporarily rate limited. Your progress is saved. Try again after \(time)."
    case .dailyQuota:
      return
        "The AI provider's daily quota is used up. Your progress is saved. Try again when the quota resets."
    case .accessDenied:
      return
        "AI access was denied. Check Firebase AI Logic and App Check for this app. Your files are safe in Needs Review."
    case .configuration:
      return
        "AI is not configured correctly. Check the Gemini service and model in Firebase. Your files are in Needs Review."
    case .offline:
      return "AI needs an internet connection. Your progress is saved; reconnect and try again."
    case .temporary:
      return "The AI service is temporarily unavailable. Your progress is saved. Try again shortly."
    case .invalidResponse:
      return
        "AI could not read part of its response. Completed files are saved; try again for the remaining files."
    case .other:
      return "AI could not organise the remaining files. Your progress is saved. Try again."
    }
  }

  static func classify(_ error: Error, now: Date) -> AIRequestFailure {
    if let failure = error as? AIRequestFailure {
      return failure
    }
    let nsError = error as NSError
    let details = "\(error) \(error.localizedDescription)".lowercased()
    if nsError.domain == NSURLErrorDomain {
      if nsError.code == NSURLErrorNotConnectedToInternet
        || nsError.code == NSURLErrorNetworkConnectionLost
      {
        return .offline
      }
      if nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorCannotConnectToHost {
        return .temporary
      }
    }
    if details.contains("resource_exhausted") || details.contains("resourceexhausted")
      || details.contains("429") || details.contains("quota exceeded")
    {
      if details.contains("perday") || details.contains("per_day") || details.contains("daily") {
        return .dailyQuota
      }
      let delay = retryDelay(in: details) ?? 60
      return .rateLimited(retryAt: now.addingTimeInterval(max(1, delay)))
    }
    if details.contains("403") || details.contains("401") || details.contains("permission_denied")
      || details.contains("permissiondenied") || details.contains("app check")
      || details.contains("appcheck") || details.contains("unauthenticated")
    {
      return .accessDenied
    }
    if details.contains("404") || details.contains("400") || details.contains("not_found")
      || details.contains("invalid_argument") || details.contains("service_disabled")
    {
      return .configuration
    }
    if details.contains("503") || details.contains("502") || details.contains("500")
      || details.contains("unavailable") || details.contains("deadline_exceeded")
    {
      return .temporary
    }
    return .other
  }

  static func retryDelay(in text: String) -> TimeInterval? {
    let patterns = [
      #"retry(?:delay|_delay| after| in)[\s\"':=]*(\d+(?:\.\d+)?)\s*s"#,
      #"retry-after[\s\"':=]*(\d+(?:\.\d+)?)"#,
    ]
    for pattern in patterns {
      guard let range = text.range(of: pattern, options: .regularExpression),
        let number = text[range].range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression),
        let seconds = Double(text[number])
      else {
        continue
      }
      return seconds
    }
    return nil
  }
}
