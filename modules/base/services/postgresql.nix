{ pkgs, lib, ... }:
{
  services.postgresql = {
    # NOTE: bumping the major needs a pg_upgrade of the existing clusters *before* deploying
    package = lib.mkOverride 900 pkgs.postgresql_18;
    enableJIT = lib.mkDefault true;
  };
}
