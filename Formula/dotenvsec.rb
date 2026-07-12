class Dotenvsec < Formula
  desc "Fail-closed SOPS environment loader"
  homepage "https://github.com/philband/dotenvsec"
  version "0.3.0"
  license "MIT"

  depends_on "sops"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/philband/dotenvsec/releases/download/v0.3.0/dotenvsec_0.3.0_darwin_arm64.tar.gz"
      sha256 "3096790717efc9e84a0b4ff45dbeba2fd51d28cfd13bde3a684786d9b89eaff2"
    else
      odie "dotenvsec supports macOS arm64 only; Intel macOS is not supported"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/philband/dotenvsec/releases/download/v0.3.0/dotenvsec_0.3.0_linux_amd64.tar.gz"
      sha256 "a28bfc487767ccbab396fa94f3ae2a967149466438942e81e21c7c29d694bf28"
    else
      odie "dotenvsec supports Linux amd64 only; Linux arm64 is not supported"
    end
  end

  def install
    bin.install "dotenvsec"
    bin.install "dotenvsec-provider-sops"
  end

  test do
    assert_match "dotenvsec", shell_output("#{bin}/dotenvsec --help")
    assert_predicate bin/"dotenvsec-provider-sops", :executable?
  end
end
