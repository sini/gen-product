# gen-product — lib/show.nix : display helpers for ERROR MESSAGES ONLY.
#
# Not a rendering API. den-hoag owns user-facing rendering ("sini@axon-01"); gen-product renders just
# enough to name the offending dimension and value in a throw (strings are display only, never data).
{ prelude }:
let
  inherit (prelude) map concatStringsSep attrNames;

  showCell =
    pg: coords:
    concatStringsSep ", " (
      map (d: "${d}=${pg.__renderEntry pg.__def.factorsByDim.${d} coords.${d}}") (attrNames coords)
    );

  showSubset = dims: "{" + concatStringsSep "," dims + "}";
in
{
  show = {
    cell = showCell;
    subset = showSubset;
  };
}
