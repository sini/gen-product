# golden-den-fixture (§1 convergence table): one end-to-end golden pinning the den convergences that
# gen-product's generality buys — user@host config = a CELL; the real fleet = RESTRICT by membership;
# class-share = QUOTIENT by class; matrix instantiation = CELLS; settings specificity = the
# CONTAINMENT CHAIN feeding a fold-shaped consumer.
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

  # the FULL product (every user on every host) …
  full = gp.productN "cartesian" [ hf uf ];
  # … restricted to the REAL fleet: not every user exists on every host (policy-emitted membership).
  fleet = gp.restrict full {
    relations = [
      {
        dims = [ "host" "user" ];
        pairs = [
          { host = hosts.H_axon01; user = users.U_sini; }
          { host = hosts.H_axon02; user = users.U_sini; }
          { host = hosts.H_blade01; user = users.U_vic; }
        ];
      }
    ];
  };

  # the sini@axon-01 CELL.
  siniAxon = gp.cell fleet { host = hosts.H_axon01; user = users.U_sini; };
  siniAxonCoords = gp.coordsOf fleet siniAxon;

  # class-share: QUOTIENT the host graph by class.
  hostsGraph = {
    nodes = builtins.attrNames hosts;
    edges = _: [ ];
    parent = _: null;
    nodeData = id: hosts.${id};
  };
  classShare = gp.quotient hostsGraph { classOf = h: h.class; };

  # matrix instantiation: the CELLS of the fleet.
  matrix = map (c: { h = c.host.name; u = c.user.name; }) (gp.cells fleet);

  # settings specificity: the CONTAINMENT CHAIN for the sini@axon-01 cell, consumed as an ordinary
  # layer list. A fold-shaped consumer labels each layer by its fixed-dimension subset and takes the
  # MOST-SPECIFIC (last) as the winner — exactly how gen-settings would position a user@host override.
  chain = gp.containmentChain fleet { host = hosts.H_axon01; user = users.U_sini; } (
    gp.linearizeByDimOrder [ "host" "user" ]
  );
  layerLabels = map (r: gp.show.subset (lib.sort lib.lessThan (builtins.attrNames r.fixed))) chain;
  winner = lib.last layerLabels;
in
{
  flake.tests.golden-den-fixture = {
    # the fleet has exactly the three real user@host cells (sparse, not the 3×2 full grid).
    test-fleet-is-sparse = {
      expr = matrix;
      expected = [
        { h = "axon-01"; u = "sini"; }
        { h = "axon-02"; u = "sini"; }
        { h = "blade-01"; u = "vic"; }
      ];
    };
    # the sini@axon-01 cell round-trips to its coordinate identities.
    test-sini-axon-cell = {
      expr = {
        host = siniAxonCoords.host.name;
        user = siniAxonCoords.user.name;
      };
      expected = {
        host = "axon-01";
        user = "sini";
      };
    };
    # class-share collapses axon-01/axon-02 into cortex, blade-01 into blade.
    test-class-share = {
      expr = map (C: {
        class = (classShare.nodeData C).class.name;
        members = map (m: hosts.${m}.name) (classShare.nodeData C).members;
      }) classShare.nodes;
      expected = [
        {
          class = "cortex";
          members = [ "axon-01" "axon-02" ];
        }
        {
          class = "blade";
          members = [ "blade-01" ];
        }
      ];
    };
    # the containment chain is the den-default specificity ladder (count-major).
    test-specificity-ladder = {
      expr = layerLabels;
      expected = [
        "{}"
        "{host}"
        "{user}"
        "{host,user}"
      ];
    };
    # the most-specific layer (the user@host cell) wins by position — no new precedence rule.
    test-most-specific-wins = {
      expr = winner;
      expected = "{host,user}";
    };
  };
}
