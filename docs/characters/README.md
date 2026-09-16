# 兩位可選角色：32×32 美術整合

尺寸依使用者確認維持 32×32，並非宣稱原作使用此尺寸。
原作作者說明使用 40×40：https://munieloom.nomaki.jp/diaboro/dia-car.htm
這裡參考其格子地城角色表現，保留本專案 16×16 邏輯佔格。

## 已接入

- Wylder：參考使用者提供的銀色雙翼頭盔、灰黑圍巾、深藍戰袍、劍盾造型。
- Revenant／復仇者：淡色長髮與面紗、藍花冠、灰白長裙及赤腳。
- 兩張為先前以 imagegen 設計、依指定尺寸匯出的透明 PNG，這次接入真實遊戲。
- 選角畫面按角色名稱切換，再按 Enter dungeon；HUD 顯示選中角色。
- CharacterCatalog 與各自的 selectable.tres 提供角色外觀，無須改 world.gd。

## 素材與動畫範圍

每位目前一張待機圖，所有移動方向共用此圖；原有移動、攻擊位移、受擊閃白仍能播放。
尚未完成八方向姿勢、逐幀走路／攻擊／死亡圖集。兩位沿用同一套原型 knight 數值與裝備；本次沒有實作復仇者召喚或其他角色技能。
選角卡上的放大圖直接引用同一 PNG，沒有另用高解析插畫冒充遊戲素材。

## 真實預覽

selection.png、wylder-gameplay.png、revenant-gameplay.png 都由 Godot 的 viewport framebuffer 擷取，原生 576×324。
同名 -2x.png 為 framebuffer 的 nearest 2 倍輸出（1152×648），沒有拼接角色或生成地城畫面。
測試會實際點選選角按鈕、進入 Game、完成等待回合並讓敵人行動，再擷取圖片。

執行 Run-Character-QA.cmd 可重跑。繼承原型已知的退出 ObjectDB／Resource 警告；未在這次進行記憶體生命週期重構。
