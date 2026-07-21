import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    self.contentViewController = flutterViewController

    // ウィンドウタイトル
    self.title = "SIGNAL FLOW Show Time"

    // 最小ウィンドウサイズ
    self.minSize = NSSize(
      width: 520,
      height: 500
    )

    // 起動時のウィンドウサイズ
    self.setContentSize(
      NSSize(
        width: 900,
        height: 650
      )
    )

    // 起動時に画面中央へ配置
    self.center()

    RegisterGeneratedPlugins(
      registry: flutterViewController
    )

    super.awakeFromNib()
  }
}