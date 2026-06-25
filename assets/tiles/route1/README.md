Route 1 Tile Sheet
==================

Drop a 32px tile sheet at:

`assets/tiles/route1/route1_tiles.png`

The overworld loader expects a single horizontal row of 32x32 tiles, so the full image should be 416x32 pixels. Tiles are read in this order:

1. Dirt / walkable ground
2. Grass / wild encounter tile
3. Wall / generic blocked tile
4. Sign / blocked readable tile
5. NPC placeholder / blocked interactable tile
6. Tree / blocked scenery tile
7. House / blocked scenery tile
8. Cottage roof left / blocked scenery tile
9. Cottage roof middle / blocked scenery tile
10. Cottage roof right / blocked scenery tile
11. Cottage wall left / blocked scenery tile
12. Cottage door / blocked scenery tile
13. Cottage wall right / blocked scenery tile

The cottage pieces are painted on the `Objects` layer as a 3x2 block:

```text
roof left   roof middle   roof right
wall left   door          wall right
```

Route maps can use two symbol layers:

- `rows` is the ground layer. Use this for dirt, grass, and other terrain the player stands on.
- `overlay_rows` is the object layer. Use this for transparent signs, trees, houses, NPC markers, and other objects that should sit over ground.

Sign, tree, house, and NPC tiles should usually have transparent pixels where the ground should show through.

If this file is missing or too narrow, the game uses generated placeholder colors so tests and gameplay still run.
