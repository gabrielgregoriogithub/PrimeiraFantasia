# Stage 5 animation source audit

2026-09-05, America/Sao_Paulo. Preconditions read and met: Stage 3 DONE_AND_PRESENT, STATIC_GODOT_PREVIEW PASS; Stage 4 DONE_AND_PRESENT, GODOT EQUIPMENT PREVIEW PASS, commit 282a4bf. Approved rig, bone mapping and equipment report consulted. No gameplay integration.

| Source | Findings | Decision |
|---|---|---|
| Local warrior_animated_v1 through v5 GLBs | Existing legacy library. `tools/blender/animate_warrior_v1.py` uses a small set of authored joint poses; Walk has four principal samples plus loop endpoint, and attack returns to rest. This does not establish professional foot contact or V3 combat guard quality. | Do not automatically reuse. No legacy clip copied. |
| Local Blender helpers | `common/animation_utils.py` creates/keyframes actions; it is a utility, not a motion library. | May use Blender for baking and local editing. |
| Tripo animation retarget | Current documentation supports v1.0 biped presets; actual service rejects this Mixamo-spec rig with error 1004: retarget of Mixamo bones unsupported. | Two submitted tasks failed. No further paid retries; preserve approved skeleton. |
| Adobe Mixamo | Official FAQ permits use in games; requires Adobe ID. No suitable downloaded Mixamo clips found in this project. | Available alternative, not used. |
| Quaternius Universal Animation Library Standard | Official free CC0 package, humanoid clips, root-motion-disabled variant. | Download for motion inspection and Blender retarget. Not yet an approved V3 library. |

Tripo requests: `work/tripo/retarget_batch_1.json` (idle/walk/slash/chop/hurt), `retarget_batch_2.json` (fall). Tasks d5bc207a-e948-46b1-9ccc-f9a7c2dd31dc and 4d7a446b-a7cc-4c43-815c-a3d7f5ec1615. Expected 50+10 credits, but both failed: balance before and after 705, final frozen 0; observed net cost 0. The task response does not provide credits_consumed. Initial six-item batch was synchronously rejected (maximum five) before task creation, recorded in retarget.json; this file's pending label does not mean a live task.

No clips have passed motion QA at this audit point. Retarget must preserve the 53-bone equippable variant, original body weights and fixed socket transforms. In-place motion, contact, impacts and terminal Death require separate validation.

Sources consulted:

- https://developers.tripo3d.ai/en/docs/animations-retarget
- https://developers.tripo3d.ai/en/pricing
- https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- https://quaternius.com/packs/universalanimationlibrary.html
- https://quaternius.itch.io/universal-animation-library
