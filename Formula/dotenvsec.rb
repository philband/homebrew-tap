class Dotenvsec < Formula
  desc "Fail-closed SOPS environment loader"
  homepage "https://github.com/philband/dotenvsec"
  version "0.8.0"
  license "MIT"

  depends_on "sops"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/philband/dotenvsec/releases/download/v0.8.0/dotenvsec_0.8.0_darwin_arm64.tar.gz"
      sha256 "3413031747846e17fbe606e5984aa038e2c296a9fe2dc4b8b2c3df1380d8559d"
    else
      odie "dotenvsec supports macOS arm64 only; Intel macOS is not supported"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/philband/dotenvsec/releases/download/v0.8.0/dotenvsec_0.8.0_linux_amd64.tar.gz"
      sha256 "35d75a20ff70d1b561ce38dbac76a87c524d3a01b41ebaa50d7ecefd339fcc56"
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
