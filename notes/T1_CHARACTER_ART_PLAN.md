# T1 Character Art Pass

Target: integrate supplied Wylder/Revenant eight-direction combat art without regressing T0 gameplay.

- logical frame: 64x64 normalized from supplied source canvases
- grounded pivot: 24,60
- direction rows: S, SW, W, NW, N, NE, E, SE
- rows 0-7: idle/facing
- rows 8-15: melee attack key pose
- runtime QA must validate both characters and all eight directions
- existing T0 246/246 gate remains mandatory before Web deployment
