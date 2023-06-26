{ targetPlatform
, runCommand
, wrapBintoolsWith
, wrapCCWith
, buildIosSdk, targetIosSdkPkgs
, xcode
, lib
}:

let

minSdkVersion = targetPlatform.minSdkVersion or "9.0";

in

rec {
  sdk = rec {
    name = "ios-sdk";
    type = "derivation";
    outPath = xcode + "/Contents/Developer/Platforms/${platform}.platform/Developer/SDKs/${platform}${version}.sdk";
    platform = targetPlatform.xcodePlatform;
    version = targetPlatform.sdkVer;
  };

  clang-unwrapped = rec {
    name = "clang-ios";
    type = "derivation";
    outPath = xcode + "/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr";
    platform = targetPlatform.xcodePlatform;
    version = targetPlatform.sdkVer;
  };

  binutils-unwrapped = rec {
    name = "binutils-ios";
    type = "derivation";
    outPath = xcode + "/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr";
    platform = targetPlatform.xcodePlatform;
    version = targetPlatform.sdkVer;
  };

  binutils = wrapBintoolsWith {
    libc = targetIosSdkPkgs.libraries;
    bintools = binutils-unwrapped;
    overrideTargetPrefix = "";
    extraBuildCommands = lib.optionalString (sdk.platform == "iPhoneSimulator") ''
      echo "-platform_version ios-simulator ${minSdkVersion} ${sdk.version}" >> $out/nix-support/libc-ldflags
    '' + lib.optionalString (sdk.platform == "iPhoneOS") ''
      echo "-platform_version ios ${minSdkVersion} ${sdk.version}" >> $out/nix-support/libc-ldflags
    '' + lib.optionalString (sdk.platform == "AppleTVOS") ''
      echo "-platform_version tvos ${minSdkVersion} ${sdk.version}" >> $out/nix-support/libc-ldflags
    '' + lib.optionalString (sdk.platform == "AppleTVSimulator") ''
      echo "-platform_version tvos-simulator ${minSdkVersion} ${sdk.version}" >> $out/nix-support/libc-ldflags
    '';
  };

  clang = (wrapCCWith {
    cc = clang-unwrapped;
    bintools = binutils;
    libc = targetIosSdkPkgs.libraries;
    libcxx = targetIosSdkPkgs.libraries;
    isClang = true;
    # This was in an older version of this, but I am not sure what
    # this is used for.
    # extraPackages = [ "${sdk}/System" ];
    extraBuildCommands = ''
      tr '\n' ' ' < $out/nix-support/cc-cflags > cc-cflags.tmp
      mv cc-cflags.tmp $out/nix-support/cc-cflags
      echo "-target ${targetPlatform.config}" >> $out/nix-support/cc-cflags
      echo "-isysroot ${sdk}" >> $out/nix-support/cc-cflags
      echo "-isystem ${sdk}/usr/include/c++/v1" >> $out/nix-support/cc-cflags
      echo "-L${sdk}/usr/lib" >> $out/nix-support/cc-ldflags
      echo "-isystem ${sdk}/usr/include${lib.optionalString (lib.versionAtLeast "10" sdk.version) " -isystem ${sdk}/usr/include/c++/4.2.1/ -stdlib=libstdc++"}" >> $out/nix-support/cc-cflags
    '' + lib.optionalString (sdk.platform == "iPhoneSimulator") ''
      echo "-mios-simulator-version-min=${minSdkVersion}" >> $out/nix-support/cc-cflags
    '' + lib.optionalString (sdk.platform == "iPhoneOS") ''
      echo "-miphoneos-version-min=${minSdkVersion}" >> $out/nix-support/cc-cflags
    '' + lib.optionalString (sdk.platform == "AppleTVSimulator") ''
      echo "-mappletvsimulator-version-min=${minSdkVersion}" >> $out/nix-support/cc-cflags
    '' + lib.optionalString (sdk.platform == "AppleTVOS") ''
      echo "-mappletvos-version-min=${minSdkVersion}" >> $out/nix-support/cc-cflags
    '';
  }) // {
    inherit sdk;
  };

  libraries = let sdk = buildIosSdk; in runCommand "libSystem-prebuilt" {
    passthru = {
      inherit sdk;
    };
  } ''
    if ! [ -d ${sdk} ]; then
        echo "You must have version ${sdk.version} of the ${sdk.platform} sdk installed at ${sdk}" >&2
        exit 1
    fi
    ln -s ${sdk}/usr $out
  '';
}
