# V2 Pet QA Rubric

Do not package a pet until every section passes.

## Geometry And Package

- Final atlas is exactly `1536x2288`, 8 columns x 11 rows, with `192x208` cells.
- `pet.json` contains `spriteVersionNumber: 2` and points to the packaged spritesheet.
- Used cells are non-empty; unused standard-row cells are transparent.
- Fully transparent pixels have zero RGB residue.
- The 8x9 intermediate atlas is never packaged.
- `qa/review.json` has no errors.
- Standard rows use component extraction unless `stable-slots` was deliberately approved after playback review.
- Coherent look rows recover their ordered pose groups and pass near-edge clipping checks after shared-scale registration into final cells.

## Character And Style

- Silhouette, proportions, face, expression language, material, palette, lighting, markings, and props remain the same across all 11 rows.
- The pet reads clearly inside a `192x208` cell in the chosen style.
- No frame introduces an unintended character, object, logo, text, scene, or effect.

## Standard Animation

- Rows `0-8` contain the exact required frame counts and recognizable state semantics.
- Loops do not pop, reverse cadence, face the wrong direction, or remain effectively static.
- The first idle frame works as a reduced-motion still.
- `waiting`, `running`, `review`, and `failed` remain visually distinct.

## Look Directions

- All 16 directions are present in fixed clockwise order and visibly distinct from neutral/rest.
- Cardinal directions read unmistakably as up, right, down, and left; diagonals and intermediates read in the correct quadrant.
- `qa/look-directions.png` includes full-body and zoomed head/upper-body views.
- `qa/direction-semantics.json` 为每个方向记录 `verdict`（`pass` / `warning` / `fail`）、`expected`、`observed`、`reason`；不得遗留 `fail`，`warning` 须按主 SKILL 的 Direction Acceptance Policy 复核并留证。
- `qa/look-continuity.json` has no unexplained holes, center jumps, area jumps, or local difference outliers.
- Eyes, eyelids, head, body, appendages, and props follow the pet-specific look mechanics plan.
- No whole-sprite rotation, replacement/googly eyes, visual clipping, seam bands, or transparent interior holes.
- A repaired direction is approved by an independent visual QA worker or explicit user inspection, not the repairing parent alone.

## Repair Policy

按主 SKILL 的 Repair Workflow 先区分错误类别及严重度：确定性问题先修复处理流程，`minor` 按规则复核留证，只有源图 `major` 错误才重新生成最小受影响行。修复范围为一条标准行或一条完整连贯方向行，不把独立生成的修复单元拼入最终方向行。修复后重跑受影响的组装、确定性验证、独立方向 QA、连续性测量和语义检查；所有重试遵守 Time Budget And Convergence 的停止条件。
