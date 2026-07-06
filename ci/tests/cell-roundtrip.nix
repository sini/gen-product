# cell-roundtrip (law P6): coordsOf ∘ cell = id on entries (by id_hash), cell ∘ coordsOf = id on
# cellIds — for full, restricted, and sliced products. On slices, addressing speaks FREE coordinates
# only (fixed dims are unknown-dim); the slice round-trip additionally checks full-product
# reconstruction via `.product.base`.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) registryFactor hosts users;
  gp = genProduct;

  hf = registryFactor "host" hosts;
  uf = registryFactor "user" users;
  p = gp.productN "cartesian" [
    hf
    uf
  ];

  hashes = coords: lib.mapAttrs (_: e: e.id_hash) coords;

  roundtrips =
    prod:
    lib.all (
      c:
      let
        cid = prod.__cell c;
        back = gp.coordsOf prod cid;
      in
      hashes back == hashes c && gp.cell prod back == cid
    ) (gp.cells prod);

  # restricted to two of the four host×user cells.
  restricted = gp.restrict p {
    cells = [
      {
        host = hosts.H_axon01;
        user = users.U_sini;
      }
      {
        host = hosts.H_blade01;
        user = users.U_vic;
      }
    ];
  };

  sl = gp.slice p { host = hosts.H_axon01; };
  slCellSini = gp.cell sl { user = users.U_sini; };

  namingFixedDim = builtins.tryEval (gp.cell sl { host = hosts.H_axon01; });
in
{
  flake.tests.cell-roundtrip = {
    test-full-roundtrip = {
      expr = roundtrips p;
      expected = true;
    };
    test-restricted-roundtrip = {
      expr = roundtrips restricted;
      expected = true;
    };
    # codec opacity: coordsOf recovers the same identities (id_hash) fed in.
    test-codec-opacity = {
      expr = hashes (
        gp.coordsOf p (
          gp.cell p {
            host = hosts.H_axon02;
            user = users.U_vic;
          }
        )
      );
      expected = {
        host = "H_axon02";
        user = "U_vic";
      };
    };
    # slice speaks free coords only.
    test-slice-free-dims = {
      expr = sl.product.dims;
      expected = [ "user" ];
    };
    test-slice-free-roundtrip = {
      expr = roundtrips sl;
      expected = true;
    };
    # naming a FIXED dim on a slice is an unknown-dim error.
    test-slice-fixed-dim-errors = {
      expr = namingFixedDim.success;
      expected = false;
    };
    # full-product reconstruction: base // free-coords addresses the underlying full cell, whose user
    # coordinate matches the slice's.
    test-slice-full-reconstruction = {
      expr = hashes (gp.coordsOf p (gp.cell p (sl.product.base // gp.coordsOf sl slCellSini)));
      expected = {
        host = "H_axon01";
        user = "U_sini";
      };
    };
  };
}
