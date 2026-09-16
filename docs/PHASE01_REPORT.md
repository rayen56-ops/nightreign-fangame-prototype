# Phase 01 驗收紀錄

日期：2026-09-15；引擎：Godot 4.6 stable，Windows x64。

## 結果

已建立可啟動、可繼續擴充的格子回合制原型。`tests/phase01.tscn` 在實際視窗模式執行 **66 項檢查，0 項失敗**，詳見 qa-results.json、qa-runtime.log。

| 項目 | 驗證方式與結果 |
|---|---|
| 地城 | BSP 地城有房間和上下樓入口；種子 11、22、33 均成功，地圖指紋不同 |
| 格子 | Constants.TILE_SIZE 保持 16；八方向由 InputMap 經既有 PlayerAttackMoveAction 執行 |
| 回合 | 每方向位置差恰為一格，回合數 +1；動畫結束不追加回合；撞牆不消耗回合 |
| 佔格 | 離開格清空、目的格只存一個玩家；視覺外框 32×32，不參與碰撞 |
| 外觀 | 使用獨立 Resource 指定圖集、方向、動畫列、張數和腳底錨點 |
| 敵人 | 真實隨機地圖上等待回合後，敵人的能量／行動回合處理訊號有觸發 |
| FOV／霧 | 玩家所在格可見並記入 seen；地圖存在不可見格，沿用既有遮蔽與探索記憶 |
| 裝備 | 起始武器在背包；透過 Action 卸下、穿回均成功 |
| 背包 UI | 背包與裝備頁能開啟，Modal 位於 Game/UI 畫布層 |
| 尺寸 | 原生視窗尺寸回報分別為 1152×648、576×324；邏輯畫面皆 576×324 |
| 視窗切換 | 地圖物件、回合、HP、座標、相機位置和縮放不變 |
| 畫素 | nearest、整數縮放；移動視覺位置與相機位置取整，shader 位移取整 |

## 畫面證據

- logical_standard.png、logical_pet.png：在兩種實際視窗尺寸下，由 Godot 取得的 576×324 邏輯畫面。
- render_standard.png、render_pet.png：上列畫面以 nearest 匯出成已驗證的視窗輸出尺寸；不包含桌面、視窗外框或其他應用程式。
- frame-comparison.json：兩張邏輯圖有 99.932% 像素一致，差異 127／186624 像素。活躍的粒子／環境動畫會隨截取時間變動；相機位置、zoom 與玩家位置另以程式斷言驗證完全一致。

## 修改範圍

1. project.godot：修正原本 1512×949 視窗覆寫；固定邏輯 576×324、viewport/keep、integer、pixel snap；加入 DisplayProfiles 與規定的輸入動作。
2. src/nightreign/display/：集中 STANDARD／PET／MOBILE_FUTURE 設定；F8 切換前兩者，mobile 僅保留未完成的擴充入口。
3. src/nightreign/characters/、assets/nightreign/：可替換的 Wylder 外觀資料和純視覺播放元件。
4. scenes/actor/actor.gd：加入玩家視覺接點；原有 Monster、Map 和 Action 佔格模型不變。
5. src/camera_controller.gd、actor.gdshader：格子目標、畫素取整；關閉平滑相機與平滑 zoom 過渡。
6. scenes/game 與部分 scenes/ui：將輸入讀取統一為規定名稱，保持背包、方向提示與確認／取消相容。
7. assets/generated/{world_tiles,item_sprites}.tres：原附檔與 PNG／JSON 不一致，按既有 JSON 索引重建，消除大量越界 TileSet 錯誤。
8. 主選單、啟動腳本、測試與文件；完整原檔修改清單見 modified-upstream-files.txt。

world.gd、src/actions/、BSP 生成器、FOV、Monster AI、Pathfinding、Inventory／Equipment 資料模型均未修改。原始素材和授權檔保留。

## 尚未完成／限制

- Wylder 是佔位美術；數值、物品、敵人、場景和 HUD 沿用原範例。這不是完整黑夜君臨玩法移植。
- 沒有戰技、絕招、夜王、其他渡夜者、多人、行動觸控、iOS、桌面透明或置頂。
- 原範例沒有存檔功能，本階段未新增。
- 程式結束時有 ObjectDB 與仍被引用的 Resource 警告。在完全未修改的上游副本也已重現；本階段未重構資源生命週期。測試失敗數 0 不代表引擎結束日誌毫無警告。
- 目前測試涵蓋原型主要路徑，不是完整戰鬥平衡、每種物品、長時間遊玩或所有螢幕 DPI 的驗證。

## 來源

[statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example)，於 2026-09-15 取得 main 分支壓縮檔。原始 README、MIT LICENSE 及素材作者標示完整保留。附帶 Godot 引擎的授權與第三方聲明在 runtime/。

## 交付副本檢查

完整壓縮包重新解壓後，使用包內引擎依序匯入並重跑測試，Import exit 0、QA exit 0、66 項全部通過。日誌為 release-import.log 與 release-qa.log。首次匯入前無 UID 快取，因此將 project.godot 的字型設定改為明確 res:// 檔案路徑。

