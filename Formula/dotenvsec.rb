class Dotenvsec < Formula
  desc "Fail-closed SOPS environment loader"
  homepage "https://github.com/philband/dotenvsec"
  version "0.2.0"
  license "MIT"

  depends_on "sops"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/philband/dotenvsec/releases/download/v0.2.0/dotenvsec_0.2.0_darwin_arm64.tar.gz"
      sha256 "5a3fb3f55b6f7059736f0a30fc6405536a997428a73ef9d4d4ee1e66256c87ad"
    else
      odie "dotenvsec supports macOS arm64 only; Intel macOS is not supported"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/philband/dotenvsec/releases/download/v0.2.0/dotenvsec_0.2.0_linux_amd64.tar.gz"
      sha256 "8580468aab141088b81688176eff955fea96759cff36a48d7741502cafd05bf5"
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
