{ lib
, stdenv
, fetchFromGitHub
, curl
, git
, gmp
, libsigsegv
, meson
, ncurses
, ninja
, openssl
, pkg-config
, re2c
, zlib
}:
let version = "1.10"; in
import
  (fetchFromGitHub
    {
      owner = "urbit";
      repo = "urbit";
      rev = "urbit-v${version}";
      sha256 = "sha256-kTNOu71R9yOWPBX2EGYnDotnRqMPz+XxSVYcvV0BB58=";
      fetchSubmodules = true;
    } + "/default.nix")
{
  system = stdenv.system;
}
/*stdenv.mkDerivation rec {
  pname = "urbit";
  version = "1.10";

  src = fetchFromGitHub {
  owner = "urbit";
  repo = "urbit";
  rev = "urbit-v${version}";
  sha256 = "sha256-kTNOu71R9yOWPBX2EGYnDotnRqMPz+XxSVYcvV0BB58=";
  fetchSubmodules = true;
  };

  nativeBuildInputs = [ pkg-config ninja meson ];
  buildInputs = [ curl git gmp libsigsegv ncurses openssl re2c zlib ];

  buildPhase = ''
  make build
  '';

  #postPatch = ''
  #  patchShebangs .
  #'';

  meta = with lib; {
  description = "An operating function";
  homepage = "https://urbit.org";
  license = licenses.mit;
  maintainers = with maintainers; [ mudri ];
  platforms = with platforms; linux;
  };
  }
*/
