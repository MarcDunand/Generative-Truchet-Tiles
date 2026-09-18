# Generative-Truchet-Tiles

Processing sketches that generate a Truchet-style pattern from a functionally
infinite set of tiles. Unlike classic Truchet tiles, which are built from a small
fixed set of designs, every tile here is generated randomly and independently of
its neighbours — yet the pattern is still guaranteed to satisfy:

1. Every line closes into a shape.
2. Lines join smoothly from one tile to the next.
3. No line ever makes a true sharp corner.
4. No two lines ever cross. *(newest version only)*

Each run records its output as an SVG, for plotting and CNC cutting.

**Write-up:** https://marcdunand.com/work/major-works/gentruchet

**Run it in the browser:** https://openprocessing.org/@u310940/3009739

## The three versions

| Folder | |
|---|---|
| `old_intersection_version/` | The original. Guarantees 1–3; lines are free to cross. |
| `sequential_nonintersection_version/` | First attempt at non-intersection, by incremental random walk with backtracking on collisions. |
| `parallel_nonintersection_version/` | **Current.** Achieves non-intersection by construction — all points are generated up front and every tile is then solved independently, with no backtracking. Also supports a minimum line spacing and a two-coloured fill mode. |

Each folder is its own Processing sketch. Open the `.pde` inside it; the SVG
Export library (`import processing.svg.*`) is required.

## How the current version works

Within each tile, the points along its edges are paired in a specific order:
**always close the smallest corner first**, repeatedly, until no corners remain,
then pair whatever is left however you like. Because the smallest corner is
minimal, nothing else can be inside it — so closing it never takes space another
line needed, and the argument repeats on what remains.

Because the resulting curves never cross, the drawing is two-colourable: a
region's colour is simply the parity of how many curves enclose it.

Full technical detail, including the proof and the two-colouring algorithm, is in
[`parallel_nonintersection_version/ALGORITHM.md`](parallel_nonintersection_version/ALGORITHM.md).
Marc's original hand-written notes for the non-intersecting proof are in
`Documentation/non-intersecting_solution/` (outside this repo).
