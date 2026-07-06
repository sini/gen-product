# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-product is a function of `prelude` (gen-prelude, the pure utility base). The default fetches the
# flake-locked gen-prelude rev (content-addressed via narHash, so the plain-import path stays pure and
# in lockstep with the flake output; per the gen root-file convention). Pass `prelude` explicitly to
# override (e.g. a local gen-prelude checkout).
{
  lock ? builtins.fromJSON (builtins.readFile ./flake.lock),
  fetch ?
    name:
    builtins.fetchTree (
      let
        node = lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
      in
      node
    ),
  prelude ? import "${fetch "gen-prelude"}/lib",
}:
import ./lib { inherit prelude; }
