{ bspSrc
, gitRepos
, kernel
, l4tMajorMinorPatchVersion
, lib
, runCommand
, stdenv
, buildPackages
, fetchFromGitHub
, ...
}:
let
  novacarrier-assets = fetchFromGitHub {
    owner = "MonashNovaRover";
    repo = "novacarrier-assets";
    rev = "3576101ddc254cebbf5ce06a3d6f4fbc72d8fbfe";
    hash = "sha256-41/LFjLIuYniRdDJ5RXfbOSIqWClzQ38o/a6mxK9C2Q=";
  };
  l4t-devicetree-sources = runCommand "l4t-devicetree-sources" { }
    (lib.strings.concatStrings
      ([ "mkdir -p $out ; cp ${bspSrc}/source/Makefile $out/Makefile ;" ] ++
        lib.lists.forEach
          [ "hardware/nvidia/t23x/nv-public" "hardware/nvidia/tegra/nv-public" "kernel-devicetree" ]
          (
            project:
            ''
              mkdir -p "$out/${project}"
              cp --no-preserve=all -vr "${lib.attrsets.attrByPath [project] 0 gitRepos}"/. "$out/${project}"
            ''
          )++[
          ''
			# dummy sudo function
			sudo () { $@; }
			source ${novacarrier-assets}/flash/libsetup.sh
			# Edit device tree
			export COMMON_DTSI=$out/hardware/nvidia/t23x/nv-public/nv-platform/tegra234-p3768-0000+p3767-xxxx-nv-common.dtsi
			edit_nvidia_dts $COMMON_DTSI
			cp ${novacarrier-assets}/flash/tegra234-novacarrier.dtsi $out/hardware/nvidia/t23x/nv-public/tegra234-p3768-0000.dtsi
          '']));
in
stdenv.mkDerivation (finalAttrs: {
  pname = "l4t-devicetree";
  version = "${l4tMajorMinorPatchVersion}";
  src = l4t-devicetree-sources;

  __structuredAttrs = true;
  strictDeps = true;

  inherit kernel;

  nativeBuildInputs = finalAttrs.kernel.moduleBuildDependencies;
  depsBuildBuild = [ buildPackages.stdenv.cc ];

  # See bspSrc/source/Makefile
  makeFlags = [
    "KERNEL_HEADERS=${finalAttrs.kernel.dev}/lib/modules/${finalAttrs.kernel.modDirVersion}/source"
    "KERNEL_OUTPUT=${finalAttrs.kernel.dev}/lib/modules/${finalAttrs.kernel.modDirVersion}/build"
  ];

  buildFlags = "dtbs";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"/
    # See kernel-devicetree/generic-dts/Makefile
    # The dtbs are installed to kernel-devicetree/generic-dts/dtbs
    install -Dm644 kernel-devicetree/generic-dts/dtbs/* "$out/"

    runHook postInstall
  '';
})
