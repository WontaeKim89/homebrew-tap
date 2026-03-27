class ClaudeHub < Formula
  desc "Visual dashboard for managing Claude Code harness configuration"
  homepage "https://github.com/WontaeKim89/claude-hub"
  url "https://github.com/WontaeKim89/claude-hub/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "4fec6a6831fdc7c6e8f180ef2119f14ed097d3a06aaa0e9ab29ac1482fd4f61d"
  license "MIT"

  depends_on "python@3.13"
  # Node.js 불필요: PyPI wheel에 빌드된 프론트엔드가 포함됨

  def install
    python3 = "python3.13"

    # venv 생성
    venv_dir = libexec
    system python3, "-m", "venv", venv_dir.to_s
    venv_pip = venv_dir/"bin/pip"

    # PyPI wheel로 설치 (프론트엔드 static 파일 포함, npm 빌드 불필요)
    system venv_pip, "install", "--upgrade", "pip"
    system venv_pip, "install", "claude-hub==#{version}"

    # CLI 실행 스크립트 생성
    (bin/"claude-hub").write_env_script venv_dir/"bin/claude-hub", PATH: "#{venv_dir}/bin:#{HOMEBREW_PREFIX}/bin:$PATH"
  end

  test do
    assert_match "usage", shell_output("#{bin}/claude-hub --help 2>&1")
  end
end
