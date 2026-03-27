class ClaudeHub < Formula
  desc "Visual dashboard for managing Claude Code harness configuration"
  homepage "https://github.com/WontaeKim89/claude-hub"
  # GitHub tarball은 참조용. 실제 설치는 PyPI wheel에서 수행 (소스 빌드 없음)
  url"https://github.com/WontaeKim89/claude-hub/archive/refs/tags/v0.3.7.tar.gz"
  sha256 "75f6219c9a48e1bcb13efd799424754a01455b05f1142a284d60940f7ce325f5"
  license "MIT"

  depends_on "python@3.13"

  def install
    venv_dir = libexec
    venv_python = venv_dir/"bin/python"
    venv_pip = venv_dir/"bin/pip"

    # venv 생성
    system "python3.13", "-m", "venv", venv_dir.to_s

    # PyPI wheel 설치 (소스 빌드 없음 — Xcode/hatchling 불필요)
    system venv_pip, "install", "--no-cache-dir", "claude-hub==#{version}"

    # CLI 스크립트
    (bin/"claude-hub").write_env_script venv_dir/"bin/claude-hub", PATH: "#{venv_dir}/bin:#{HOMEBREW_PREFIX}/bin:$PATH"
  end

  def post_install
    # /Applications/ClaudeHub.app 자동 생성
    app_dir = Pathname.new("/Applications/ClaudeHub.app")
    return if app_dir.exist?

    venv_python = libexec/"bin/python"

    # launcher.py
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
          print("ClaudeHub running at " + URL + " — press Ctrl+C to stop")
          try:
              while True: time.sleep(60)
          except KeyboardInterrupt:
              pass
      cleanup()
    PYTHON

    # .app 번들
    macos_dir = app_dir/"Contents/MacOS"
    macos_dir.mkpath

    launcher = macos_dir/"ClaudeHub"
    launcher.write <<~SHELL
      #!/bin/bash
      exec "#{venv_python}" "#{libexec}/launcher.py"
    SHELL
    launcher.chmod 0755

    # 아이콘 복사 (PyPI wheel의 static/ 안에 포함됨)
    resources_dir = app_dir/"Contents/Resources"
    resources_dir.mkpath
    icns_src = libexec/"lib/python3.13/site-packages/claude_hub/assets/claude-hub.icns"
    cp icns_src, resources_dir/"ClaudeHub.icns" if icns_src.exist?

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
          <key>CFBundleIconFile</key>
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

    system "codesign", "--force", "--deep", "--sign", "-", app_dir.to_s
    ohai "ClaudeHub.app installed to /Applications"
  end

  def caveats
    <<~EOS
      ClaudeHub.app has been installed to /Applications.

      Launch by:
        1. Finder → Applications → ClaudeHub (or drag to Dock)
        2. Terminal: claude-hub
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/claude-hub --help 2>&1")
  end
end
