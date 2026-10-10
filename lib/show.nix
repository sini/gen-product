# gen-product — lib/show.nix : display helpers for ERROR MESSAGES ONLY.
#
# Not a rendering API. den-hoag owns user-facing rendering ("sini@axon-01"); gen-product renders just
# enough to name the offending dimension and value in a throw (strings are display only, never data).
# One exception, stated: `subset` is also the node id of `latticeGraph` (lib/chain.nix), which takes
# it from here, so a refusal naming a subset and the lattice node for it cannot drift apart.
{ prelude }:
let
  inherit (prelude) map concatStringsSep attrNames;
  inherit (builtins) toJSON tryEval isString;

  # Render a coordinate entry for an error message — its `.name` if present, else its JSON key.
  renderEntry =
    f: entry:
    let
      t = tryEval (if entry ? name then entry.name else toJSON (f.key entry));
    in
    if t.success then (if isString t.value then t.value else toJSON t.value) else "<malformed-entry>";

  # The product is the subject, so it comes last (P2, R7): `show.node coords pg`.
  showNode =
    coords: pg:
    concatStringsSep ", " (
      map (d: "${d}=${renderEntry pg.product.def.factorsByDim.${d} coords.${d}}") (attrNames coords)
    );

  showSubset = dims: "{" + concatStringsSep "," dims + "}";
in
{
  inherit renderEntry;
  show = {
    node = showNode;
    # ── THE RETIRED NAME ──
    # A tombstone rather than a silent alias, as `cell` in ./default.nix: refused by name, and the
    # refusal names its replacement. No message interpolates anything.
    cell = throw "gen-product: `show.cell` is renamed `show.node`. A product's cell is the node a graph query takes, so the display helper takes the node's word (grammar R8); the arguments and the behaviour are unchanged.";
    subset = showSubset;
  };
}
