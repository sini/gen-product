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
        cid = gp.cell c prod;
        back = gp.coordsOf cid prod;
      in
      hashes back == hashes c && gp.cell back prod == cid
    ) (gp.cells prod);

  # restricted to two of the four host×user cells.
  restricted = gp.restrict {
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
  } p;

  sl = gp.slice { host = hosts.H_axon01; } p;
  slCellSini = gp.cell { user = users.U_sini; } sl;

  namingFixedDim = builtins.tryEval (gp.cell { host = hosts.H_axon01; } sl);
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
        gp.coordsOf (gp.cell {
          host = hosts.H_axon02;
          user = users.U_vic;
        } p) p
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
      expr = hashes (gp.coordsOf (gp.cell (sl.product.base // gp.coordsOf slCellSini sl) p) p);
      expected = {
        host = "H_axon01";
        user = "U_sini";
      };
    };
  };
}
