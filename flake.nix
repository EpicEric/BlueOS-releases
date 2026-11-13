{
  description = "Published BlueOS images and their release manifest";

  inputs = {
    # Never a branch: a release has to name exactly one BlueOS commit. The
    # revision is in the URL rather than left to flake.lock, so `nix flake
    # update` cannot move it and a release cannot silently change contents.
    blueos.url = "github:BlueRobotics/BlueOS/e29887a8bfd5efe13c5eeda2364a24bca6e5df19";
  };

  outputs =
    { blueos, ... }:
    let
      # The version a device reports is the one in its closure, written by
      # services.blueos.version and read back from etc/blueos/release.json.
      # Nothing here overrides it: `mkImage`'s `version` argument reaches
      # release.json and the generation label but not the built frontend, which
      # keeps the literal from the BlueOS commit, so overriding it would make
      # one build report two versions.
      #
      # A release tag therefore has to match the version literal in the BlueOS
      # commit being released. The workflow enforces that.
      image =
        { board }:
        blueos.lib.mkImage {
          inherit board;
          manifestUrl = "https://bluerobotics.github.io/BlueOS-releases/manifest.json";
          cache = {
            host = "https://cache.eric.dev.br";
            publicKey = "cache.eric.dev.br-1:szEyq5LCjxDCUHYSRaSFU5HdHmR7QlT+FRG3tB9QtpE=";
          };
        };
    in
    {
      nixosConfigurations = {
        blueos-pi4 = image { board = "4"; };
        blueos-pi5 = image { board = "5"; };
      };
    };
}
