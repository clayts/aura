{
  inputs,
  pkgs,
}:
{
  style = import ./style { inherit pkgs; };
  packages = import ./packages { inherit pkgs inputs; };
}
