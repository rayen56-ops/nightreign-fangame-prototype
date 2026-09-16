# M1 第一段遠征 — 實作與驗證

日期：2026-09-16。Godot 4.6 stable。定位：可通關的玩法原型，正式美術未完成。

## 本次實作

- 沿用既有格子地圖、FOV、Action、背包與裝備，加入獨立遠征規則層；成功行動後每個敵人各行動一次，失敗操作不推進回合。
- Wylder：Claw Shot／Onslaught Stake／Sixth Sense。復仇者：輪替家人召喚／Immortal March／擊殺機率亡靈。
- 角色 8 種能力等第、7 種武器及 STR／DEX／INT／FAI 補正，沒有能力門檻；角色與武器平衡數字為本作改編。
- 紅露滴聖杯瓶、入口賜福、暖石範圍回復，拾取、裝備和消耗品接回原有 Action。
- 兩層程序地牢加第三層夜王場地；入口聖劍保證提供可利用的弱點選項。
- Gladius 測試規則：固定預兆格、隔回合攻擊、收招空檔、半血增傷、聖屬性三次命中打斷。尚非原作完整招式組。
- 勝利／死亡／回選角，回訪樓層保留戰況，修正入口被敵人占據時的返回問題。
- HUD 顯示等第、小招冷卻、大招蓄積、補給及符文。危險格位於人物下方。
- 修正地圖產生器自行使用時間種子造成測試種子無法重現的問題；相同測試種子現能重現地形及敵人位置。

## 驗證證據

| 檢查 | 結果 | 報告 |
|---|---|---|
| 遠征規則與完整通關 | 64 項通過 | M1_QA.json |
| 原有地城、八方向、FOV、裝備、視窗 | 66 項通過 | qa-results.json |
| 方向小招、召喚、HUD 邊界、勝利與回選角 | 17 項通過 | M1_UI_QA.json |
| 實機選角、角色資源、背包、截圖尺寸 | 24 項通過 | characters/qa.json |

前 147 項可用根目錄 Run-Expedition-QA.cmd 重跑。24 項選角檢查可用 Run-Character-QA.cmd 重跑。

### 通關測試

固定測試種子 16092026，在真實 World.apply_player_action 流程中拾取、裝備、行走、下樓、喝水、施法及戰鬥。途中未注入血量、傷害或瞬移。測試導航可讀取整張地圖，因此這不是玩家盲探索的難度／平均時間驗收。

- Wylder：67 次測試決策，經過第 1／2／3 層，勝利，剩餘 68 HP。
- 復仇者：68 次測試決策，經過第 1／2／3 層，勝利，剩餘 44 HP。
- 獨立邊界檢查涵蓋失敗零回合、兩次致命傷、第六感、冷卻、不死到期、Boss 鎖定預兆、弱點累積、賜福不可重複刷、死亡後禁止行動及重開重置。

### 實機圖片

- m1-wylder-boss.png：Wylder 與預兆危險格。
- m1-revenant-boss.png／m1-revenant-family.png：復仇者及家人召喚。
- m1-wylder-victory.png／m1-revenant-victory.png：勝利視窗。

以上由 Godot viewport 擷取、以 nearest 整數 2 倍輸出，沒有概念圖合成。展示場景由 QA 設定位置；勝利視窗測試使用致命命中 fixture。實際三層通關的證據在 M1_QA.json，兩種驗證不混為一談。

## 未完成與限制

1. 兩位角色、敵人、Gladius 與地形仍使用暫用圖片。美術未達到使用者要求；美術工作畫格及驗收寫在 ART_DIRECTION.md。
2. Gladius 尚無三頭形象、分裂／合體、鎖鏈劍完整招式。小怪亦尚無各自完整原作行為。
3. 武器目前以補正與屬性區分；印記、法杖仍走共通攻擊流程，未完成獨立法術與武器動作。聖屬性標籤屬首版戰鬥抽象，不能視作原作武器逐項復刻。
4. VIG／MND／END／ARC 的等第尚未全部對應成長、耐力或異常機制；符文可取得但尚無消費升級。
5. 英文原型 UI；未完成中文化、存檔、音樂、長期平衡及其他角色／夜王。
6. 程式退出時仍有原上游可重現的 ObjectDB／6 resources 釋放警告。測試無 GDScript 執行錯誤；退出警告仍須後續修正，不列為「零警告」。

## 原作資料與本作規則

角色技能的辨識核心查核自 [Wylder 官方頁](https://en.bandainamcoent.eu/elden-ring/elden-ring-nightreign/characters/wylder)、[復仇者官方頁](https://en.bandainamcoent.eu/elden-ring/elden-ring-nightreign/characters/revenant)。遠征方向參照[官方入門指南](https://en.bandainamcoent.eu/elden-ring/news/elden-ring-nightreign-the-official-starter-guide)。血量、等第、機率、範圍、回合冷卻與傷害均为本作原型值。

下一個製作門檻是 M2：先把兩名人物、一個地城房間與 Gladius 的正式像素造型放進實機驗收，再擴充美術量。
