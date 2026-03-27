class ClaudeHub < Formula
  desc "Visual dashboard for managing Claude Code harness configuration"
  homepage "https://github.com/WontaeKim89/claude-hub"
  url "https://github.com/WontaeKim89/claude-hub/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "3dbf43c2f806b2a6465b86cdf74ec3145bc135659a60ec9a1835ae32fb57b36a"
  license "MIT"

  depends_on "python@3.13"
  depends_on "uv"

  def install
    # uv로 venv 생성 + PyPI wheel 설치 (pip보다 빠르고 캐시 문제 없음)
    venv_dir = libexec
    system "uv", "venv", "--python", "python3.13", venv_dir.to_s
    system "uv", "pip", "install", "--python", (venv_dir/"bin/python").to_s, "claude-hub==#{version}"

    # CLI 스크립트
    (bin/"claude-hub").write_env_script venv_dir/"bin/claude-hub", PATH: "#{venv_dir}/bin:#{HOMEBREW_PREFIX}/bin:$PATH"
  end

  def post_install
    # /Applications/ClaudeHub.app 자동 생성
    app_dir = Pathname.new("/Applications/ClaudeHub.app")
    return if app_dir.exist?

    venv_python = libexec/"bin/python"

    # launcher.py — uvicorn 서버 시작 + 브라우저 오픈
    (libexec/"launcher.py").write <<~PYTHON
      import os, sys, time, signal, urllib.request, threading, webbrowser
      LOCK = os.path.expanduser("~/.claude-hub/app.lock")
      URL = "http://localhost:3847"
      os.makedirs(os.path.dirname(LOCK), exist_ok=True)

      def is_running():
          try:
              urllib.request.urlopen(URL, timeout=2)
              return True
          except:
              return False

      def cleanup(*_):
          try: os.remove(LOCK)
          except: pass

      if os.path.exists(LOCK) and is_running():
          webbrowser.open(URL)
          sys.exit(0)

      with open(LOCK, "w") as f:
          f.write(str(os.getpid()))
      signal.signal(signal.SIGTERM, cleanup)
      signal.signal(signal.SIGINT, cleanup)

      import uvicorn
      from claude_hub.main import create_app
      app = create_app()

      def run_server():
          uvicorn.run(app, host="127.0.0.1", port=3847, log_level="warning")

      threading.Thread(target=run_server, daemon=True).start()
      for _ in range(30):
          if is_running(): break
          time.sleep(0.3)

      try:
          import webview
          window = webview.create_window("ClaudeHub", URL, width=1280, height=820, min_size=(900, 600), background_color='#09090b')
          webview.start()
      except ImportError:
          webbrowser.open(URL)
          import select
          print("ClaudeHub running at " + URL + " — press Ctrl+C to stop")
          try:
              while True: time.sleep(60)
          except KeyboardInterrupt:
              pass
      cleanup()
    PYTHON

    # .app 번들 구조 생성
    macos_dir = app_dir/"Contents/MacOS"
    macos_dir.mkpath

    # 실행 스크립트
    launcher = macos_dir/"ClaudeHub"
    launcher.write <<~SHELL
      #!/bin/bash
      exec "#{venv_python}" "#{libexec}/launcher.py"
    SHELL
    launcher.chmod 0755

    # Info.plist
    (app_dir/"Contents/Info.plist").write <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleName</key>
          <string>ClaudeHub</string>
          <key>CFBundleDisplayName</key>
          <string>ClaudeHub</string>
          <key>CFBundleIdentifier</key>
          <string>com.claudehub.app</string>
          <key>CFBundleVersion</key>
          <string>#{version}</string>
          <key>CFBundleExecutable</key>
          <string>ClaudeHub</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>NSHighResolutionCapable</key>
          <true/>
          <key>NSDesktopFolderUsageDescription</key>
          <string>ClaudeHub needs access to Desktop to manage Claude Code project configurations.</string>
          <key>NSDocumentsFolderUsageDescription</key>
          <string>ClaudeHub needs access to Documents to manage Claude Code project configurations.</string>
      </dict>
      </plist>
    PLIST

    # codesign (ad-hoc)
    system "codesign", "--force", "--deep", "--sign", "-", app_dir.to_s

    ohai "ClaudeHub.app installed to /Applications — launch from Spotlight"
  end

  def caveats
    <<~EOS
      ClaudeHub.app has been installed to /Applications.

      Note: Spotlight may not index unsigned apps.
      You can launch ClaudeHub by:
        1. Open Finder → /Applications → double-click ClaudeHub
        2. Or run in terminal: claude-hub
        3. Or drag ClaudeHub.app to your Dock for quick access
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/claude-hub --help 2>&1")
  end
end
