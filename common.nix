{ lib, ... }: {
  options.isDesktop = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
