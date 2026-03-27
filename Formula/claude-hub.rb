class ClaudeHub < Formula
  desc "Visual dashboard for managing Claude Code harness configuration"
  homepage "https://github.com/WontaeKim89/claude-hub"
  url "https://github.com/WontaeKim89/claude-hub/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "4fec6a6831fdc7c6e8f180ef2119f14ed097d3a06aaa0e9ab29ac1482fd4f61d"
  license "MIT"

  depends_on "python@3.13"
  depends_on "node"

  def install
    python3 = "python3.13"

    # venv 생성
    venv_dir = libexec
    system python3, "-m", "venv", "--system-site-packages", venv_dir.to_s
    venv_pip = venv_dir/"bin/pip"

    # PyPI에서 wheel로 설치 (hatchling 빌드 문제 우회)
    system venv_pip, "install", "--upgrade", "pip"
    system venv_pip, "install", "claude-hub==#{version}"

    # 프론트엔드 빌드
    cd "src/client" do
      system "npm", "install"
      system "npm", "run", "build"
    end

    # 빌드된 정적 파일 복사
    static_dir = venv_dir/"lib/python3.13/site-packages/claude_hub/static"
    mkdir_p static_dir
    cp_r "src/client/dist/.", static_dir

    # bin 링크
    (bin/"claude-hub").write_env_script venv_dir/"bin/claude-hub", PATH: "#{venv_dir}/bin:#{HOMEBREW_PREFIX}/bin:$PATH"
  end

  test do
    assert_match "claude-hub", shell_output("#{bin}/claude-hub --help 2>&1", 0)
  end
end
