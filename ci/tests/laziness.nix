# laziness (law P10): with a factor whose `nodes = throw …`, constructing the product and running
# `cell` (incl. pointwise not-a-node validation), `coordsOf`, `slice`, `fiber`, `projectTo`,
# `containmentChain` (construction + coords validation, not slice forcing), and `edges`/`nodeData`/
# `parent` of cartesian/tensor/strong products all SUCCEED — possible because not-a-node/not-a-member
# detection is pointwise, never a `nodes` scan (Kahn 1974 demand discipline). Documented exceptions are
# asserted positively: lexicographic edges in a non-final dim force trailing nodes; cells/nodes force
# all factor node lists; quotient forces input nodes.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) idFactor;
  gp = genProduct;

  # A factor whose node list explodes when forced, but whose edges/nodeData are fine pointwise.
  throwingGraph = {
    nodes = throw "P10: nodes must not be forced";
    edges = id: if id == "t0" then [ "t1" ] else if id == "t1" then [ "t0" ] else [ ];
    parent = _: null;
    nodeData = id: id;
  };
  tf = idFactor "t" throwingGraph;
  gy = idFactor "y" fx.gB;

  succeeds = e: (builtins.tryEval e).success;
  # force a value deeply enough to trip a lazy throw.
  force = v: builtins.deepSeq v true;

  cart = gp.productN "cartesian" [ tf gy ];
  tens = gp.productN "tensor" [ tf gy ];
  strong = gp.productN "strong" [ tf gy ];
  # tf trailing (final) AND the leading factor sits at a dead-end node (a1 has no out-edge), so no
  # earlier dim advances → the trailing factor's nodes are never enumerated. Safe.
  lex = gp.productN "lexicographic" [ (idFactor "ya" fx.gA) tf ];
  # tf trailing, but the leading factor advances (b0 -> b1), so the non-final move forces the trailing
  # (throwing) factor's nodes → throws (the documented lexicographic exception).
  lexLeadThrow = gp.productN "lexicographic" [ (idFactor "yb" fx.gB) tf ];

  cid = gp.cell cart { t = "t0"; y = "b0"; };
in
{
  flake.tests.laziness = {
    # construction never forces nodes.
    test-construct-cartesian = {
      expr = succeeds (force cart.product.dims);
      expected = true;
    };
    # cell (with pointwise not-a-node validation) succeeds under throwing nodes.
    test-cell-succeeds = {
      expr = succeeds (force cid);
      expected = true;
    };
    test-coordsOf-succeeds = {
      expr = succeeds (force (gp.coordsOf cart cid));
      expected = true;
    };
    # adjacency of cartesian/tensor/strong never forces nodes.
    test-cartesian-edges = {
      expr = succeeds (force (cart.edges cid));
      expected = true;
    };
    test-tensor-edges = {
      expr = succeeds (force (tens.edges (gp.cell tens { t = "t0"; y = "b0"; })));
      expected = true;
    };
    test-strong-edges = {
      expr = succeeds (force (strong.edges (gp.cell strong { t = "t0"; y = "b0"; })));
      expected = true;
    };
    test-nodeData-succeeds = {
      expr = succeeds (force (cart.nodeData cid));
      expected = true;
    };
    # slice / fiber / projectTo never force nodes.
    test-slice-succeeds = {
      expr = succeeds (force ((gp.slice cart { t = "t0"; }).product.dims));
      expected = true;
    };
    test-fiber-succeeds = {
      expr = succeeds (force ((gp.fiber cart "t" "t0").product.dims));
      expected = true;
    };
    test-projectTo-succeeds = {
      expr = succeeds (force (gp.projectTo cart "y").projection.dim);
      expected = true;
    };
    # containmentChain construction + coords validation, without forcing slice structure.
    test-chain-construction-succeeds = {
      expr = succeeds (
        force (
          map (r: {
            inherit (r) free rank;
            fixed = lib.mapAttrs (_: v: v) r.fixed;
          }) (gp.containmentChain cart { t = "t0"; y = "b0"; } (gp.linearizeByDimOrder [ "t" "y" ]))
        )
      );
      expected = true;
    };
    # lexicographic with the throwing factor TRAILING (final) and no earlier dim advancing: safe.
    test-lex-trailing-throw-safe = {
      expr = succeeds (force (lex.edges (gp.cell lex { ya = "a1"; t = "t0"; })));
      expected = true;
    };

    # ── documented exceptions (positive-force assertions) ──
    # cells forces all factor node lists → throws.
    test-cells-forces-nodes = {
      expr = succeeds (force (gp.cells cart));
      expected = false;
    };
    # nodes forces the node lists → throws.
    test-nodes-forces = {
      expr = succeeds (force cart.nodes);
      expected = false;
    };
    # lexicographic edges in a NON-final dim force the trailing factor's nodes → throws.
    test-lex-nonfinal-forces-trailing = {
      expr = succeeds (
        force (lexLeadThrow.edges (gp.cell lexLeadThrow { yb = "b0"; t = "t0"; }))
      );
      expected = false;
    };
    # quotient structural access forces the input's nodes → throws.
    test-quotient-forces-input-nodes = {
      expr = succeeds (force (gp.quotient throwingGraph { classOf = id: { id_hash = id; }; }).nodes);
      expected = false;
    };
  };
}
