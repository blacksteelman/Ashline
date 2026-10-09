# ASHLINE — состояние разработки (обновляется каждую сессию)

Godot 4.6.3 (Forward+, Vulkan), Blender 4.3.2, Python 3 + Pillow/NumPy/OpenCV.
Ветка разработки: `claude/multiplayer-military-fps-6avclq`. Предыдущая история (версии 0.2–0.7, Codex) — в `SESSION_HANDOFF.md` и `README.md`.

## Что сделано в сессии v0.8 (Claude)

### Освещение и атмосфера — `scripts/atmosphere.gd`
- HDRI-небо Poly Haven `kloofendal_38d_partly_cloudy_puresky` (CC0), солнце выровнено по солнцу HDRI (38°).
- AgX tonemap, glow, лёгкая цветокоррекция, дымка с aerial perspective.
- Пресеты: 0 Performance, 1 Balanced (SSAO), 2 Quality (+SDFGI, SSIL, SSR, объёмный туман), 3 Ultra. По умолчанию 2.
- `--graphics=N` в аргументах запуска переопределяет пресет (для тестов).

### Новая карта FOUNDRY DISTRICT — `scripts/arena.gd`
- Полностью новая раскладка 72×90 м: главная улица N–S, поперечная E–W, четыре квартала:
  жилой дом (2 играбельных этажа, лестница, комнаты с окнами на перекрёсток), торговый ряд,
  литейный цех (мостки на 3.2 м, кран, станки), контейнерный двор с погрузочной рампой, переулки.
- Периметр — дома из модульного фасадного набора Poly Haven (CC0), второе кольцо и дальний силуэт.
- Пропсы Poly Haven (CC0): бетонные блоки, сетчатые заборы, столбы ЛЭП, бочки, ящики, генераторы и т.д.
  Пайплайн: `tools/fetch_polyhaven.py` (исходники в `assets/thirdparty/polyhaven`, в git не хранятся,
  скачиваются заново с проверкой md5) → `tools/build_kit.py` (Blender: объединение, origin, decimate,
  AABB для коллизий в `assets/kit/kit.json`) → `assets/kit/*.glb`.
- PBR-материалы ambientCG (CC0): `tools/fetch_ambientcg.py` → `assets/textures/<key>_{albedo,normal,orm}`;
  мировой трипланарный шейдер `assets/shaders/surface.gdshader` (вариации тона, грязь у основания).
  Таблица материалов — `scripts/surfaces.gd`.
- Фасадные модули объединены в MultiMesh по ячейкам 24 м; конструктивные боксы — StaticBatch.
- Слой коллизий 8 (`Arena.CLIP_LAYER`): блокирует игроков, но не пули (витрины, края мостков).
- Навигация строится из физики при загрузке (`build_navigation`): многоуровневые узлы, связи через
  профиль пола (ступень ≤ 0.3 м), переход через пороги. ~7600 узлов, ~1.5 с.
- Проверка: `tests/map_v8.gd` (спавны, маршруты на все уровни, физический подъём бота по лестницам).

### Оружие от первого лица — `tools/build_viewmodels.py`, `scripts/first_person_rig.gd`
- Реальное оружие: M4A1, Mk18 CQBR (производная CC0 M4A1), винтовка Мосина 91/30 с ПУ (Poly Haven CC0),
  Walther P38 (Poly Haven CC0). Классы: Rifleman / Breacher / Sniper (`scripts/arsenal.gd`).
- Руки: CC0 MakeHuman/para FPS rig. ВАЖНО (исправлено): риг нужно открывать через open_mainfile,
  проверять сторону (правая кисть на +X), разъединять кости перед сдвигом и определять сторону вершин
  по весам. Ранее сетка была смещена от костей на 10–25 см — отсюда «резиновые» руки.
- Хват: центр ладони ставится на реальную поверхность (луч вдоль нормали ладони), пальцы
  сгибаются вокруг оси плоскости пальца до касания сетки оружия (BVH). Диагностика:
  `--solve-only`, ортопроекции `/tmp/claude-0/s/ortho.py`-подобный скрипт (см. историю), сообщения AXES/REACH/GRIP.
- Анимации запекаются в Blender: idle, draw, sprint, reload, reload_empty (+ cycle для болтовки).
- В Godot: собственный шейдер `assets/shaders/viewmodel.gdshader` — FOV оружия 52° (44° в ADS) независимо от
  мирового FOV и глубина впереди мира (оружие не проходит сквозь стены). Глобальная uniform
  `viewmodel_fov_scale` объявлена в project.godot.
- Камуфляж рукавов: `tools/camo.py` генерирует мультикам-, ЕМР- и ММ14-подобные узоры
  (`assets/textures/camo_*`). Настройка UNIFORM CAMOUFLAGE в меню; по умолчанию Aegis — мультикам, Ember — ЕМР.
- Модели для третьего лица: `assets/viewmodels/world_*.glb` (ещё не подключены к солдатам).

## Известные проблемы / не сделано
- Руки: хват исправлен, но мелкие позы (перезарядка болтовки, большой палец, позиция в кадре)
  требуют дальнейшей полировки по кадрам из движка. Смотреть `tests/capture_weapons.gd`.
- Солдаты-боты всё ещё старые грубые модели Codex (`soldier_0/1.glb`). План: тело MakeHuman (MPFB2, CC0)
  + форма с камуфляжем + бронежилет/шлем, либо CC-BY модели со Sketchfab (нужен токен API от пользователя).
- АК-74/MP5 и другие реальные модели: на Sketchfab есть CC-BY, нужен токен `SKETCHFAB_TOKEN`.
- Сеть: lag compensation и буфер интерполяции не сделаны.
- Режимы (Domination и др.), перки по слотам, create-a-class — не сделаны.
- Миникарта HUD рассчитана на старую карту 64 м — нужно обновить под 72×90.
- Старые тесты v3–v7 частично завязаны на старую карту; functional/regression_v3/playthrough проходят.

## Как проверять
```sh
godot --headless --editor --path . --import            # после изменения ассетов
godot --headless --path . --script tests/functional.gd
godot --headless --path . --script tests/map_v8.gd
godot --headless --path . -- --bot-test --seed=801 --matches=1
# реальные кадры (нужен X/Vulkan: Xvfb :99 + mesa lavapipe)
DISPLAY=:99 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json godot --path . --resolution 960x540 --script tests/capture_v8.gd -- --graphics=1
DISPLAY=:99 ... godot --path . --script tests/capture_weapons.gd -- --graphics=1
blender -b --python tools/build_viewmodels.py -- ar carbine sniper pistol [--preview] [--solve-only]
```
Окружение: Godot ставится из GitHub releases в /opt/godot; Blender 4.3.2 с download.blender.org в /opt/blender;
`apt-get install mesa-vulkan-drivers` для lavapipe. SDFGI на программном рендере ~5 с/кадр — для итераций использовать --graphics=1.
