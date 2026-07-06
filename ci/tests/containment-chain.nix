# containment-chain (law P13): the chain is a linear extension of subset inclusion (S ⊂ S' ⟹ S
# earlier), contains exactly the 2^|D| subsets, ∅ first and D last. `byRank` obeys the descending
# rank-vector rule; `linearizeByDimOrder` obeys the count-major key ( |S|, sortDescending ranks ) —
# the two differ on incomparable equal-inclusion pairs ({env,host} vs {user}). Both reject degenerate
# inputs (missing/duplicate); a bad comparator errors; equal inputs give byte-equal chains.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) registryFactor hosts users envs;
  gp = genProduct;

  ef = registryFactor "env" envs;
  hf = registryFactor "host" hosts;
  uf = registryFactor "user" users;
  p = gp.productN "cartesian" [ ef hf uf ];

  c = {
    env = envs.E_prod;
    host = hosts.H_axon01;
    user = users.U_sini;
  };

  # each chain entry → its sorted fixed-dimension names (identifies the subset).
  chainSubsets = lin: map (r: lib.sort lib.lessThan (builtins.attrNames r.fixed)) (gp.containmentChain p c lin);

  dimOrder = gp.linearizeByDimOrder [ "env" "host" "user" ];
  ranked = gp.linearizations.byRank {
    env = 1;
    host = 2;
    user = 3;
  };

  # linear-extension check over the produced order: for all i<j positions, set_i is never a superset
  # of set_j.
  isLinearExtension =
    sets:
    let
      n = lib.length sets;
      subsetOf = a: b: lib.all (x: lib.elem x b) a;
    in
    lib.all (
      i:
      lib.all (
        j:
        # if set_j ⊂ set_i (strict) then j must come before i; here i<j so this must NOT happen
        !(subsetOf (lib.elemAt sets j) (lib.elemAt sets i) && lib.elemAt sets j != lib.elemAt sets i)
      ) (lib.range (i + 1) (n - 1))
    ) (lib.range 0 (n - 1));

  stripped = lin: map (r: { fixed = lib.mapAttrs (_: e: e.id_hash) r.fixed; inherit (r) free rank; }) (gp.containmentChain p c lin);

  # degenerate inputs.
  missingRank = builtins.tryEval (chainSubsets (gp.linearizations.byRank { env = 1; host = 2; }));
  dupRank = builtins.tryEval (chainSubsets (gp.linearizations.byRank { env = 1; host = 2; user = 2; }));
  missingDimOrder = builtins.tryEval (chainSubsets (gp.linearizeByDimOrder [ "env" "host" ]));
  dupDimOrder = builtins.tryEval (chainSubsets (gp.linearizeByDimOrder [ "env" "host" "user" "host" ]));
  # extra keys/names for non-product dims are IGNORED (a shared fleet-wide table applies unchanged).
  extraRankKey = chainSubsets (gp.linearizations.byRank { env = 1; host = 2; user = 3; cell = 9; });
  extraDimName = chainSubsets (gp.linearizeByDimOrder [ "extra" "env" "host" "user" ]);

  badComparator = builtins.tryEval (
    chainSubsets (a: b: lib.length (builtins.attrNames a.fixed) > lib.length (builtins.attrNames b.fixed))
  );

  # restricted product chain + not-a-member coords.
  restricted = gp.restrict p {
    cells = [ c { env = envs.E_prod; host = hosts.H_blade01; user = users.U_vic; } ];
  };
  chainOnRestricted = map (r: lib.sort lib.lessThan (builtins.attrNames r.fixed)) (
    gp.containmentChain restricted c dimOrder
  );
  nonMemberChain = builtins.tryEval (
    gp.containmentChain restricted { env = envs.E_dev; host = hosts.H_axon02; user = users.U_vic; } dimOrder
  );
in
{
  flake.tests.containment-chain = {
    # count-major golden — the den default shape.
    test-dimorder-golden = {
      expr = chainSubsets dimOrder;
      expected = [
        [ ]
        [ "env" ]
        [ "host" ]
        [ "user" ]
        [ "env" "host" ]
        [ "env" "user" ]
        [ "host" "user" ]
        [ "env" "host" "user" ]
      ];
    };
    # top-rank-interleave golden — byRank puts {env,host} BEFORE {user}.
    test-byrank-golden = {
      expr = chainSubsets ranked;
      expected = [
        [ ]
        [ "env" ]
        [ "host" ]
        [ "env" "host" ]
        [ "user" ]
        [ "env" "user" ]
        [ "host" "user" ]
        [ "env" "host" "user" ]
      ];
    };
    # the two linearizations differ exactly on {env,host} vs {user}.
    test-orders-differ = {
      expr = chainSubsets dimOrder == chainSubsets ranked;
      expected = false;
    };
    # exactly 2^3 subsets, ∅ first, D last.
    test-chain-cardinality = {
      expr = lib.length (chainSubsets dimOrder);
      expected = 8;
    };
    test-chain-ends = {
      expr = {
        first = builtins.head (chainSubsets dimOrder);
        last = lib.last (chainSubsets dimOrder);
      };
      expected = {
        first = [ ];
        last = [ "env" "host" "user" ];
      };
    };
    # linear-extension property for both.
    test-dimorder-linear-extension = {
      expr = isLinearExtension (chainSubsets dimOrder);
      expected = true;
    };
    test-byrank-linear-extension = {
      expr = isLinearExtension (chainSubsets ranked);
      expected = true;
    };
    # determinism: equal inputs → byte-equal (identity-stripped) chains.
    test-determinism = {
      expr = stripped dimOrder == stripped dimOrder;
      expected = true;
    };
    # degenerate inputs rejected.
    test-missing-rank-errors = {
      expr = missingRank.success;
      expected = false;
    };
    test-duplicate-rank-errors = {
      expr = dupRank.success;
      expected = false;
    };
    test-missing-dim-order-errors = {
      expr = missingDimOrder.success;
      expected = false;
    };
    test-duplicate-dim-order-errors = {
      expr = dupDimOrder.success;
      expected = false;
    };
    # extra table keys / list names ignored.
    test-extra-rank-key-ignored = {
      expr = extraRankKey == chainSubsets ranked;
      expected = true;
    };
    test-extra-dim-name-ignored = {
      expr = extraDimName == chainSubsets dimOrder;
      expected = true;
    };
    # bad comparator (orders a superset before its subset).
    test-bad-comparator-errors = {
      expr = badComparator.success;
      expected = false;
    };
    # chain works on a restricted product.
    test-chain-on-restricted = {
      expr = chainOnRestricted;
      expected = [
        [ ]
        [ "env" ]
        [ "host" ]
        [ "user" ]
        [ "env" "host" ]
        [ "env" "user" ]
        [ "host" "user" ]
        [ "env" "host" "user" ]
      ];
    };
    # not-a-member coords on a restricted product error.
    test-chain-non-member-errors = {
      expr = nonMemberChain.success;
      expected = false;
    };
  };
}
