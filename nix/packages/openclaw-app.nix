{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.4.11";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.4.11/OpenClaw-2026.4.11.zip";
    hash = "sha256-DHp8JPMmhSquYamUaGX0yXGkRi1obwJcZmY6fEcS0u0=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/openclaw-app-install.sh}";

  meta = with lib; {
    description = "OpenClaw macOS app bundle";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
