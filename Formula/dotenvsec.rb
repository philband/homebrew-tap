class Dotenvsec < Formula
  desc "Fail-closed SOPS environment loader"
  homepage "https://github.com/philband/dotenvsec"
  version "0.1.0"
  license "MIT"

  depends_on "sops"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/philband/dotenvsec/releases/download/v0.1.0/dotenvsec_0.1.0_darwin_arm64.tar.gz"
      sha256 "de86a2410f28a4d67c69a7eb5350d81d973a02446e18ca654d52f6415bf3a5ce"
    else
      odie "dotenvsec supports macOS arm64 only; Intel macOS is not supported"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/philband/dotenvsec/releases/download/v0.1.0/dotenvsec_0.1.0_linux_amd64.tar.gz"
      sha256 "524b72545dc61c22cd8a8adf3d8dbc2b8d56dab0e662ce3ed70abadf44828d7e"
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
