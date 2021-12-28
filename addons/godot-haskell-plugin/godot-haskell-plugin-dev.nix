{ mkDerivation, aeson, base, base64-bytestring, bytestring, clock, lib
, colour, containers, directory, extra, http-client
, http-client-tls, http-types, inline-c, iso8601-time, lens, linear
, process, raw-strings-qq, stdenv, stm, text, time, unix, uuid
, vector, fetchFromGitHub, haskellPackages, devBuild ? false, onNixOS ? false, ordered-containers, process-extras, dhall, hspec, QuickCheck, cabal-install, profileBuild ? false, safe-exceptions, io-streams
}:
mkDerivation {
  pname = "godot-haskell-plugin";
  version = "0.1.0.0";
  src = ./.;
  libraryHaskellDepends = [
    aeson base base64-bytestring bytestring clock colour containers
    directory extra http-client http-client-tls
    http-types inline-c iso8601-time lens linear process raw-strings-qq
    stm text time unix uuid vector ordered-containers process-extras dhall hspec QuickCheck safe-exceptions io-streams
  ];
  homepage = "https://github.com/SimulaVR/Simula#readme";
  license = lib.licenses.asl20;

  doHaddock = false;
  doCheck = false;
  enableLibraryProfiling = profileBuild;
}
