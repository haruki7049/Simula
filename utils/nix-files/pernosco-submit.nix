{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,

  python3,
  awscli2,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  name = "pernosco-submit";

  src = fetchFromGitHub {
    owner = "Pernosco";
    repo = "pernosco-submit";
    rev = "49bff241a8859f9470bfbbd71920798f9bf8daf9";
    hash = "sha256-1WgttCvlBF5wsnSCyYHPnfWpwS3jTnMtaeEKPygsUfQ=";
  };

  buildInputs = [
    python3
    awscli2
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  dontBuild = true;

  installPhase = ''
    # Copy pernosco-submit source code
    mkdir -p $out/share
    cp -r . $out/share/pernosco-submit

    # Patch shebang & PATH
    patchShebangs --host $out/share/pernosco-submit/pernosco-submit
    makeWrapper $out/share/pernosco-submit/pernosco-submit $out/share/pernosco-submit/.pernosco-submit-wrapped \
      --prefix PATH : ${lib.makeBinPath finalAttrs.buildInputs}

    # Create a symlink
    mkdir -p $out/bin
    ln -s $out/share/pernosco-submit/.pernosco-submit-wrapped $out/bin/pernosco-submit
  '';
})
