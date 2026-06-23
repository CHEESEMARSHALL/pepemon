Route 1 Tile Sheet
==================

Drop a 16px tile sheet at:

`assets/tiles/route1/route1_tiles.png`

The overworld loader expects a single horizontal row of 16x16 tiles in this order:

1. Dirt / walkable ground
2. Grass / wild encounter tile
3. Wall / generic blocked tile
4. Sign / blocked readable tile
5. NPC placeholder / blocked interactable tile
6. Tree / blocked scenery tile
7. House / blocked scenery tile

If this file is missing or too narrow, the game uses generated placeholder colors so tests and gameplay still run.
