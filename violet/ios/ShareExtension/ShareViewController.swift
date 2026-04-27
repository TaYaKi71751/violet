import MobileCoreServices
import Social
import UIKit

class ShareViewController: UIViewController {
  private var didStartHandling = false
  private var didComplete = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.alpha = 0.01
    view.backgroundColor = .clear
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    guard !didStartHandling else {
      return
    }

    didStartHandling = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
      self?.complete()
    }
    handleSharedItems()
  }

  private func handleSharedItems() {
    guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
      complete()
      return
    }

    for item in extensionItems {
      for provider in item.attachments ?? [] {
        let urlType = kUTTypeURL as String
        let plainTextType = kUTTypePlainText as String

        if provider.hasItemConformingToTypeIdentifier(urlType) {
          loadSharedItem(provider, typeIdentifier: urlType)
          return
        }

        if provider.hasItemConformingToTypeIdentifier(plainTextType) {
          loadSharedItem(provider, typeIdentifier: plainTextType)
          return
        }
      }
    }

    complete()
  }

  private func loadSharedItem(_ provider: NSItemProvider, typeIdentifier: String) {
    provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, _ in
      DispatchQueue.main.async {
        guard let self else {
          return
        }

        guard let url = self.violetShareURL(from: item) else {
          self.complete()
          return
        }

        self.openContainingApp(url)
      }
    }
  }

  private func violetShareURL(from item: NSSecureCoding?) -> URL? {
    guard let sharedUrl = sharedURLString(from: item) else {
      return nil
    }

    var components = URLComponents()
    components.scheme = "xyz.project.violet"
    components.host = "share"
    components.queryItems = [
      URLQueryItem(name: "url", value: sharedUrl),
    ]
    return components.url
  }

  private func sharedURLString(from item: NSSecureCoding?) -> String? {
    if let url = item as? URL {
      return url.absoluteString
    }

    guard let string = item as? String else {
      return nil
    }

    return firstURL(in: string) ?? string.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func firstURL(in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s]+"#) else {
      return nil
    }

    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: nsRange),
          let range = Range(match.range, in: text) else {
      return nil
    }

    return String(text[range])
  }

  private func openContainingApp(_ url: URL) {
    if openURL(url) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.complete()
      }
      return
    }

    extensionContext?.open(url) { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self?.complete()
      }
    }
  }

  private func complete() {
    guard !didComplete else {
      return
    }

    didComplete = true
    extensionContext?.completeRequest(returningItems: nil)
  }

  @objc @discardableResult private func openURL(_ url: URL) -> Bool {
    var responder: UIResponder? = self

    while let currentResponder = responder {
      if let application = currentResponder as? UIApplication {
        if #available(iOS 18.0, *) {
          application.open(url, options: [:], completionHandler: nil)
          return true
        }

        return application.perform(#selector(openURL(_:)), with: url) != nil
      }

      responder = currentResponder.next
    }

    return false
  }
}
