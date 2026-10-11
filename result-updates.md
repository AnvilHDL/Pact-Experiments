# Result Updates

The results in [README.md](README.md#main-results) improve on those reported in the paper after fixes to the compiler and its optimizations. The optimizations described below explain the main causes of these improvements:

- **Smaller generated circuits:** code generation removes redundant control state, shares delay registers, and avoids duplicated offer logic. These changes affect area and timing.
- **Faster compatibility checks:** the checker avoids duplicating automaton states, prunes transition combinations during product construction, and solves the resulting game with less storage and repeated work. Parallel product exploration also reduces checking time.

These changes preserve behaviour:

- every generated circuit matches its SystemVerilog reference cycle for cycle (`make equiv`);
- the checker's verdicts do not depend on these optimizations or on the number of threads.

## Code generation

Each thread compiles to an event graph. Its events are realised by control state: wait states for blocking handshakes, delay counters, offer-selection registers, data selectors and start flags. This control state can be redundant when an action cannot block or when several paths have the same timing. The optimizations below remove or share that state and reduce duplicated offer logic. Those marked *O3* are enabled only at `-O 3`, which `make synthesis` and `make equiv` use.

| Optimization | What changes |
| --- | --- |
| Non-blocking exchanges | `isend`/`irecv` (`#m` in session types) complete in the current cycle, so they need no wait state or acknowledge logic. The type checker guarantees the peer is ready. |
| No wait state on instant actions | No wait-state register is allocated for an action that cannot block. |
| Blocking offers as retried instant offers | A blocking `xoffer` is lowered to a one-cycle non-blocking offer inside a recursion with a one-cycle delay. This removes one waiting handshake per arm. |
| Tree-order selectors | An `xoffer` selector can rotate in binary-tree order, as `rr_arb_tree` does. An N-way round-robin arbiter is then a single offer instead of N copies. |
| Lean offer joins (*O3*) | When every arm of an offer has the same fixed latency, all arms finish in the same cycle. The join then needs no per-arm completion registers. |
| Data from the active sender (*O3*) | One message may be sent from several events, with data that lives only in the handshake cycle. The data mux is then driven by whichever send event is active, and no stored selector register is needed. |
| Shared loop delay (*O3*) | Branches that end a loop iteration with the same one-cycle delay are joined first, then share a single delay register. |
| Shared delays, no start flag (*O3*) | One-cycle delays that only feed an OR into the same event share one register, since a delayed OR equals an OR of delays. A loop whose last step is such a delay starts from that register reset to 1, so it needs no separate start flag. |

## Compatibility checking

Compatibility checking first builds an automaton for each member, then composes these automata to represent their interactions, and finally solves a game over the product. The optimizations reduce the work required at each of these three stages:

1. **Type automata.** Each member's session type becomes a symbolic type automaton. Its transitions carry guards over immediate and future offers, and clock transitions mark cycle boundaries.
2. **Product.** The members of a pool are composed into a product automaton that synchronises their messages. `make compat` uses the simultaneous product (`-debug-choice 3`), which also resolves messages exchanged within the same cycle.
3. **Game.** The product becomes a game arena. Compatibility means that the start node wins this objective:
   - clocks recur on every path;
   - on every fair path, every member's progress marker recurs.

   Each fair choice (`++`, `^^`, `fair if`, `fair xoffer`, `F`) is an annotation by which the programmer states intent. Each such choice has its own identifier, and its arms are labelled with it. A path is fair when every arm that is enabled infinitely often is taken infinitely often.

### Type automata

At the first stage, branch joins prevent duplication of the rest of a type. Graph-based propagation and indexed operations then reduce the work needed to build and compose its automaton.

- **Branch joins with ε-edges.** In a sequence `L; R`, the final states of `L` join through one non-clock ε-transition, and `R` is built once. Without the join, each offer, `try` or choice whose arms end separately would duplicate the rest of the automaton. N branch points in a row would therefore give 2^N copies. With it, the automaton stays linear in the size of the type. Future offers propagate backwards through non-clock edges, so each branch end still advertises what follows the join. For example, the arbiter's master (18 one-cycle `try`s) has 144 states instead of about 4.8 million.
- **Future offers by strongly connected components.** The messages a state may still offer before the next clock edge are collected in one pass over the strongly connected components of the non-clock graph, instead of by enumerating paths.
- **Indexed insertion.** Transitions are bucketed by their endpoints, so adding one, and merging its label with an existing transition, takes constant time instead of a scan of every transition.
- **Indexed parallel composition.** In the fast check, `A || B` is a pairwise product that looks up each state's outgoing transitions through an index.

### Product

At the product stage, the checker avoids fully enumerating transition combinations by rejecting inconsistent partial combinations early. It also distributes exploration across cores and uses an index to merge edges in the fast check.

- **Pruned combination search.** For each product state, the simultaneous check looks for the combinations of member transitions whose guards are consistent. It builds each combination member by member in a depth-first search. The next member is the one that shares the most messages with those already placed. A partial combination is abandoned as soon as it fails a condition that adding more members cannot repair:
  - members must agree on whether the clock advances;
  - every message must be paired with its partner;
  - a member's synchronisation with partners already chosen must be consistent.

  Surviving combinations get the full consistency check. The result is the same set of successors as the full enumeration of the cartesian product, which grows exponentially with the number of members.
- **Parallel, order-preserving search.** The product is explored one breadth-first level at a time. Each level's work is split into chunks and checked on several cores (`-j N`). Successors are then added sequentially in the original order, so the product, including its state numbering, is identical for any number of threads.
- **Indexed edge merging.** The fast check's product merges parallel edges between the same pair of states through an index.

### Game

At the final stage, compact storage, counters and worklists reduce graph-processing overhead. The solver also avoids arena copies for progress conditions and restricts the exact fairness check to a candidate winning region.

- **Integer arena.** Arena nodes are integers. Edges are stored in compressed arrays, each with a clock flag and a bitmask of the progress markers it carries.
- **Linear attractors.** Each universal node keeps a counter of unresolved edges. An existential node is attracted on its first good edge. The predecessor index is built once per graph.
- **Worklist dead-end analysis.** The nodes forced into the failure sink are found with a worklist.
- **Generalized Büchi without monitor copies.** The progress conditions are solved directly as a generalized Büchi fixpoint, without degeneralizing into one arena copy per member. In each outer round, the clock region and every member's progress region are computed from the same region, in parallel, and intersected.
- **Per-choice fairness in two steps.**
  1. *Per-node fixpoint.* Fairness is first assumed per arena node: a node visited infinitely often takes each of its enabled arms infinitely often. This assumption is stronger than per-choice fairness, so the region it computes contains the exact winning region. If this step rejects, the verdict is final.
  2. *Exact check.* Otherwise, the per-choice condition is checked only inside that region. It is solved as a generalized Rabin game. An arm creates a subgame only if the adversary can be kept from leaving its nodes through that arm. This restriction keeps the recursion shallow.
