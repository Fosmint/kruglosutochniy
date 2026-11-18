class_name Layers
extends RefCounted

## Слои коллизий (Physics)
const PHYS_WORLD: int = 1
const PHYS_PLAYER: int = 2
const PHYS_INTERACT: int = 4
const PHYS_CUSTOMER: int = 8

## Слои рендера (VisualInstance3D.layers / Camera3D.cull_mask)
## 1 = видят все камеры (основная, CCTV, зеркало)
## 2 = видит только основная камера (аномалия «нет отражения» и реальное тело «двойника»)
## 4 = видит только камера CCTV (двойник на камере и галлюцинации при низком рассудке)
const VIS_ALL: int = 1
const VIS_MAIN_ONLY: int = 2
const VIS_CCTV_ONLY: int = 4

const MASK_CAM_MAIN: int = VIS_ALL | VIS_MAIN_ONLY
const MASK_CAM_CCTV: int = VIS_ALL | VIS_CCTV_ONLY
const MASK_CAM_MIRROR: int = VIS_ALL
