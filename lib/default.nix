{ ... }:
{
  idp = import ./idp.nix;
  gitInsteadOfEnv = import ./git-insteadof.nix;
}
