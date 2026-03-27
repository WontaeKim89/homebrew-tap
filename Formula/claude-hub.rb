class ClaudeHub < Formula
  include Language::Python::Virtualenv

  desc "Visual dashboard for managing Claude Code harness configuration"
  homepage "https://github.com/WontaeKim89/claude-hub"
  url "https://github.com/WontaeKim89/claude-hub/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "00983115d956d2f4e7789a0f3809e82db4ee53b25df5ecbe61b5b159980af4cc"
  license "MIT"

  depends_on "python@3.13"
  depends_on "node"

  def install
    # Python 가상환경 생성 및 패키지 설치
    venv = virtualenv_create(libexec, "python3.13")
    venv.pip_install_and_link buildpath

    # 프론트엔드 빌드
    cd "src/client" do
      system "npm", "install"
      system "npm", "run", "build"
    end

    # 빌드된 정적 파일을 패키지 내부로 복사
    static_dir = libexec/"lib/python3.13/site-packages/claude_hub/static"
    mkdir_p static_dir
    cp_r "src/client/dist/.", static_dir
  end

  test do
    assert_match "claude-hub", shell_output("#{bin}/claude-hub --help 2>&1", 0)
  end
end
