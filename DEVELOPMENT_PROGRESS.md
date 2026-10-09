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
- Модели для третьего лица: `assets/viewmodels/world_*.glb` — крепятся к узлу `WeaponSocket` солдата.

### Солдаты — `tools/build_soldiers.py` → `assets/characters/soldier_{aegis,ember}.glb`
- Тело MakeHuman через MPFB2 (CC0), риг cmu_mb. Экипировка из ассетов сообщества MakeHuman:
  рубашка и брюки с камуфляжем (Aegis — мультикам, Ember — ЕМР, затайлено ×3–3.4 и затемнено),
  плитник с подсумками, шлем KZ45 (Aegis) или противогаз с капюшоном (Ember), берцы, перчатки. Лицензии — `LICENSES.md`.
- Анимации: бег/бег назад/стрейф/спринт/присед-ходьба из мокапа CMU (BVH, ретаргет через мировые дельты
  поворотов, автоматический поиск цикла, корень на месте); верх тела заменён стойкой с прикладом у плеча,
  руки — IK к рукояти и цевью. Idle, CrouchIdle, Jump, Reload (левая рука: магазин → подсумок → магазин),
  Death (колени → падение ничком) — процедурные. Всё запекается и экспортируется NLA-треками.
- Кость `Weapon` (дочерняя `Chest`) + пустышка `WeaponSocket`: в Godot туда вставляется `world_<model>.glb`
  (`Art.world_weapon`), вспышка у ботов — из маркера Muzzle (`Fighter.world_muzzle`).
- Модель смотрит в +Z (Blender −Y); `Art.soldier` оборачивает её узлом с поворотом на 180°.
- Важные грабли: MPFB `feet_on_ground` сдвигает меш, но не риг → риг поднимается вручную; после
  переименования костей нужно переименовать группы вершин; ключи позы ставятся до `frame_set`, иначе
  depsgraph перезаписывает позу; материалы MakeHuman экспортируются как BLEND → принудительно OPAQUE.
- Подготовка окружения: MPFB2 в `~/.config/blender/4.3/extensions/user_default/mpfb`, паки ассетов
  (makehuman_system_assets_cc0, pants01_cc0, shoes01_cc0, gloves01_cc0, hats02_cc0, equipment03_cc-by,
  shirts02_ccby, masks02_ccby) в его папку данных; BVH скачиваются автоматически в `$ASHLINE_BVH`.
- Проверка: `tests/capture_soldiers.gd` (все клипы обеих команд + сокет оружия).

### Сеть — интерполяция и компенсация лага (`scripts/game.gd`, `scripts/fighter.gd`)
- Хост ведёт `server_clock` и историю позиций бойцов (0.6 с); снапшоты несут метку времени.
- Клиент оценивает смещение часов по самому быстрому снапшоту и рисует чужих игроков на
  `INTERP_DELAY`=100 мс в прошлом, интерполируя между снапшотами (экстраполяция ≤100 мс, телепорт — щелчок).
- Выстрел клиента несёт `view_clock()`; хост проверяет попадание по позициям, которые видел стрелок
  (откат ≤250 мс). Тела нельзя сдвинуть и сразу опросить в одном кадре физики, поэтому при откате мир
  проверяется лучом, а бойцы — аналитически цилиндрами (`Game.trace`).
- Тесты: `tests/netcode_v8.gd` (12 проверок), `python3 tests/network_local_v8.py 3` (сервер + 3 клиента из
  редактора). Сценарий `--net-test` теперь по времени, а не по числу снапшотов (на загруженной машине
  снапшоты приходят пачками).

### Профессиональные ассеты со Sketchfab (CC-BY, токен пользователя в ~/.sketchfab_token, не в git)
- `tools/fetch_sketchfab.py` скачивает исходники в `assets/thirdparty/sketchfab/` (в git не хранятся).
- Оружие от первого лица — наборы ccransh: руки FP Arms + ACR (коллиматор), AK-74M, MPA 30 SST, снайперская
  винтовка, Springfield XD; анимации draw/idle/walk/run/fire/reload/reload_full. `tools/prepare_fp_sets.py`
  копирует glTF в `assets/viewmodels/fp_*` с текстурами 2K JPEG.
- `scripts/fp_set_rig.gd` (FPSetRig): кость Head_Cam совмещается с камерой каждый кадр (авторская анимация камеры
  сохраняется), циклы idle/walk/sprint по скорости, выстрел/перезарядка поверх (перезарядка синхронизирована с
  таймером), ADS — линия прицела (rear/front в системе ствола, привязанной к кости оружия) выводится на ось взгляда.
  Параметры на оружие — `Arsenal.WEAPONS[i].fp` (frame/rear/front/scale/eye/cam_offset/cam_rot), замеры — `tests/fp_sights.gd`,
  проверка видов — `tests/fp_probe.gd`, быстрый подбор положения глаза (cam_offset/cam_rot/FOV без карты) —
  `tests/fp_frame.gd`. Пружины отдачи — фиксированные подшаги (на медленных кадрах был NaN).
- Мусорные треугольники: часть вершин в наборах привязана к `_rootJoint` и тянется «нитью» через кадр —
  `FPSetRig.strip_strays` удаляет их при загрузке и при запекании (у ACR в руках ботов теперь есть магазин).
- Стекло оптики: отдельный шейдер `assets/shaders/viewmodel_glass.gdshader` (прозрачность + светящаяся марка).
- Оружие в руках ботов запекается оффлайн из тех же наборов: `tests/bake_world_weapons.gd` → `assets/viewmodels/world_fp_*.res/.cfg`.
- Солдаты — jeandiz: S.W.A.T. Operator (Aegis, форма перекрашена в OCP, снаряжение койот, шлем песочный) и FSB
  Operator (Ember). `tools/build_soldiers.py`: импорт Mixamo-рига (поза из узлов glTF делается позой покоя,
  встроенное оружие удаляется, кости переименовываются), дальше прежний ретаргет мокапа CMU и IK рук.
  Старые MakeHuman-солдаты — `--makehuman`.

### Прицел, перчатки, камуфляж (по замечаниям пользователя)
- ADS: линия визирования задаётся двумя точками, измеренными на сетках (центр диоптра/целика и вершина
  мушки), `FirstPersonRig.SIGHTS`; глаз дальше от целика (`ADS_DISTANCE` 0.17 у винтовок, 0.26 у P38).
  Раньше прицел ставился по одной точке горизонтально — мушка уходила вниз, целик закрывал вид.
- Позиция от бедра: `FirstPersonRig.HIP` — ствол ближе к центру и слегка наружу.
- Перчатка нарисована в UV-развёртке рук (`tools/paint_glove.py`): чёрная тыльная сторона, TPR-накладки,
  койотовая ладонь, усиленные кончики пальцев, манжета с липучкой, швы.
- Камуфляж Aegis — OCP / Scorpion W2 из образца армии США (общественное достояние,
  `assets/thirdparty/camo/scorpion_w2_swatch.png`, бесшовный тайл в `tools/camo.py`). ЕМР — мельче и точнее по цветам.
- Проверка реальным вводом (физика включена): `tests/capture_play.gd`.

### Перки и CREATE A CLASS (`scripts/arsenal.gd`, `scripts/frontend.gd`)
- Три яруса перков: Sleight of Hand / Scavenger; Stopping Power / Juggernaut; Lightweight / Steady Aim / Flak Jacket.
- Три слота классов редактируются в меню (имя, основное оружие, по перку из яруса), хранятся в настройках;
  по сети клиент отправляет свой класс хосту, снапшот несёт оружие и перки.

### Режимы — Team Deathmatch и Domination (`scripts/domination.gd`)
- Три точки A/B/C, захват стоянием в круге (быстрее вдвоём, заморозка при споре, вражескую сначала
  нейтрализовать), очко за каждую точку раз в 4 с, лимит 150, 10 минут; убийства очков не дают.
- Флаги с полотнищем и кольцом, значки A/B/C и полоса захвата в HUD, события в ленте; боты идут к
  ненашим точкам. Выбор режима — переключатель на экране выбора класса; `--mode=dom` для тестов.
- Тест: `tests/modes_v8.gd` (17 проверок); матч ботов `--bot-test --mode=dom` проходит.

### HUD — миникарта (`scripts/minimap.gd`)
- Подложка растрируется лучами сверху вниз из реальной геометрии при загрузке; карта вращается вместе
  с игроком, обрезана рамкой, показывает союзников, врагов только при RECON или выстреле.

## Известные проблемы / не сделано
- Руки: хват исправлен, но мелкие позы (перезарядка болтовки, большой палец, позиция в кадре)
  требуют дальнейшей полировки по кадрам из движка. Смотреть `tests/capture_weapons.gd`.
- Солдаты: пистолет в третьем лице держится стойкой винтовки (нет отдельного набора анимаций);
  нет анимаций поворота на месте и стрельбы из укрытия; пальцы — одна общая кость.
- АК-74/MP5 и другие реальные модели: на Sketchfab есть CC-BY, нужен токен `SKETCHFAB_TOKEN`.
- Снайперка: глаз поднят и отодвинут (прицел был на 7 см выше глаза, рукав закрывал кадр); перезарядку
  болтовки стоит проверить по кадрам. Прицелы ПП/пистолета — по замерам, можно доточить.
- Старые тесты v3–v7 частично завязаны на старую карту; functional/regression_v3/playthrough проходят.

## Как проверять
```sh
godot --headless --editor --path . --import            # после изменения ассетов
godot --headless --path . --script tests/functional.gd
godot --headless --path . --script tests/map_v8.gd
godot --headless --path . --script tests/netcode_v8.gd
godot --headless --path . --script tests/modes_v8.gd
python3 tests/network_local_v8.py 3
godot --headless --path . -- --bot-test --seed=801 --matches=1
# реальные кадры (нужен X/Vulkan: Xvfb :99 + mesa lavapipe)
DISPLAY=:99 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json godot --path . --resolution 960x540 --script tests/capture_v8.gd -- --graphics=1
DISPLAY=:99 ... godot --path . --script tests/capture_weapons.gd -- --graphics=1
blender -b --python tools/build_viewmodels.py -- ar carbine sniper pistol [--preview] [--solve-only]
blender -b --python tools/build_soldiers.py -- aegis ember [--preview] [--clip=Idle] [--analyze]
DISPLAY=:99 ... godot --path . --resolution 1280x720 --script tests/capture_soldiers.gd
```
Окружение: Godot ставится из GitHub releases в /opt/godot; Blender 4.3.2 с download.blender.org в /opt/blender;
`apt-get install mesa-vulkan-drivers` для lavapipe. SDFGI на программном рендере ~5 с/кадр — для итераций использовать --graphics=1.
