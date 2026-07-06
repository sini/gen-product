# slice-induced (law P7): a slice is the induced sub-product over cells extending the fixed coords,
# re-addressed over free dims. Cartesian slice ≡ product of free factors (loop-free fixed coords), and
# free-product ∪ cell self-loops when a fixed coord is looped; tensor slice edgeless when some fixed
# coord is loop-free, ≡ free tensor product when every fixed coord is looped. Slices compose.
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

  edgeMap =
    p:
    lib.listToAttrs (
      map (c: {
        name = p.product.cellOf c;
        value = lib.sort lib.lessThan (p.edges (p.product.cellOf c));
      }) (gp.cells p)
    );

  # ── cartesian, loop-free fixed coordinate ──
  cart = gp.productN "cartesian" [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gB)
  ];
  cartSlice = gp.slice cart { x = "a0"; };
  freeCart = gp.productN "cartesian" [ (idFactor "y" fx.gB) ];

  # ── cartesian, looped fixed coordinate (self-loop at every cell added) ──
  cartL = gp.productN "cartesian" [
    (idFactor "p" fx.gLoop)
    (idFactor "y" fx.gB)
  ];
  cartLSlice = gp.slice cartL { p = "l0"; };
  freeCartL = gp.productN "cartesian" [ (idFactor "y" fx.gB) ];
  cartLExpected = lib.listToAttrs (
    map (
      c:
      let
        cid = freeCartL.product.cellOf c;
      in
      {
        name = cid;
        value = lib.sort lib.lessThan (lib.unique (freeCartL.edges cid ++ [ cid ]));
      }
    ) (gp.cells freeCartL)
  );

  # ── tensor, loop-free fixed coordinate → edgeless ──
  tens = gp.productN "tensor" [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gB)
  ];
  tensSlice = gp.slice tens { x = "a0"; };

  # ── tensor, looped fixed coordinate → free tensor product ──
  tensL = gp.productN "tensor" [
    (idFactor "p" fx.gLoop)
    (idFactor "y" fx.gB)
  ];
  tensLSlice = gp.slice tensL { p = "l0"; };
  freeTensL = gp.productN "tensor" [ (idFactor "y" fx.gB) ];

  # ── slice composition ──
  tri = gp.productN "cartesian" [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gB)
    (idFactor "z" fx.gChain)
  ];
  stepwise = gp.slice (gp.slice tri { x = "a0"; }) { y = "b0"; };
  atOnce = gp.slice tri {
    x = "a0";
    y = "b0";
  };
in
{
  flake.tests.slice-induced = {
    # loop-free fixed coord: cartesian slice is graph-identical to the free product.
    test-cartesian-slice-is-free-product = {
      expr = edgeMap cartSlice;
      expected = edgeMap freeCart;
    };
    # looped fixed coord: free product PLUS a self-loop at every cell.
    test-cartesian-looped-slice-adds-selfloops = {
      expr = edgeMap cartLSlice;
      expected = cartLExpected;
    };
    # loop-free fixed coord: tensor slice is edgeless.
    test-tensor-slice-edgeless = {
      expr = lib.all (c: tensSlice.edges (tensSlice.product.cellOf c) == [ ]) (gp.cells tensSlice);
      expected = true;
    };
    # every fixed coord looped: tensor slice is the free tensor product.
    test-tensor-looped-slice-is-free-product = {
      expr = edgeMap tensLSlice;
      expected = edgeMap freeTensL;
    };
    # slices compose.
    test-slice-composition = {
      expr = edgeMap stepwise;
      expected = edgeMap atOnce;
    };
    test-slice-composition-base = {
      expr = stepwise.product.base;
      expected = atOnce.product.base;
    };
  };
}
