class Dotenvsec < Formula
  desc "Fail-closed SOPS environment loader"
  homepage "https://github.com/philband/dotenvsec"
  version "0.6.0"
  license "MIT"

  depends_on "sops"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/philband/dotenvsec/releases/download/v0.6.0/dotenvsec_0.6.0_darwin_arm64.tar.gz"
      sha256 "782536e70b49cd5f2f645bf6433b5dc8b933a6ec88d46d185a4ed92f0eb501a2"
    else
      odie "dotenvsec supports macOS arm64 only; Intel macOS is not supported"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/philband/dotenvsec/releases/download/v0.6.0/dotenvsec_0.6.0_linux_amd64.tar.gz"
      sha256 "4ba48f46581bfd968e1df833c497f59897c68ff6bd32be42dc669ae8a1520a2c"
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
