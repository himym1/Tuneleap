import FlutterMacOS
import Foundation
import Sparkle

/// Sparkle 2 host for private Cloud updates.
///
/// The Dart side passes a Bearer token through [httpHeaders]. Do not log it.
final class SparkleBridge: NSObject, FlutterPlugin, SPUUpdaterDelegate {
  static let channelName = "tuneleap/sparkle"

  private var updater: SPUUpdater?
  private var feedURL: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    let instance = SparkleBridge()
    instance.startUpdater()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func startUpdater() {
    let host = Bundle.main
    let driver = SPUStandardUserDriver(hostBundle: host, delegate: nil)
    let updater = SPUUpdater(
      hostBundle: host,
      applicationBundle: host,
      userDriver: driver,
      delegate: self
    )
    updater.clearFeedURLFromUserDefaults()
    updater.automaticallyChecksForUpdates = false
    updater.automaticallyDownloadsUpdates = false
    do {
      try updater.start()
      updater.automaticallyChecksForUpdates = false
      updater.automaticallyDownloadsUpdates = false
      self.updater = updater
    } catch {
      self.updater = nil
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard
        let args = call.arguments as? [String: Any],
        let feed = args["feedURL"] as? String,
        let url = URL(string: feed),
        url.scheme == "https"
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "https feedURL required",
            details: nil
          )
        )
        return
      }
      feedURL = url
      if let authorization = args["authorization"] as? String,
         authorization.hasPrefix("Bearer "),
         updater != nil
      {
        updater?.httpHeaders = ["Authorization": authorization]
      }
      result(updater != nil)
    case "checkForUpdates":
      guard updater != nil else {
        result(false)
        return
      }
      updater?.checkForUpdates()
      NSApp.activate(ignoringOtherApps: true)
      result(true)
    case "checkForUpdatesInBackground":
      updater?.checkForUpdatesInBackground()
      result(updater != nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    feedURL?.absoluteString
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    NSApp.activate(ignoringOtherApps: true)
  }
}
