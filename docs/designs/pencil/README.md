# Pencil 设计稿管理

## 当前情况

- 通过 Pencil MCP 生成的当前稿件名称是：`pencil-new.pen`。
- 它现在在 Pencil 编辑器会话中可见，不会自动落盘到本项目目录。
- 我在本地项目里未检索到可用的业务 `.pen` 文件（仅发现 Pencil 插件自带测试文件）。

## 目录规范

- `docs/designs/pencil/navidrome/`：Navidrome Player 相关稿件。
- `docs/designs/pencil/peq/`：PEQ 相关稿件。

## 命名规范

采用固定文件名，后续只维护，不再按日期持续新建：

- `navidrome-mobile.pen`
- `navidrome-pc.pen`
- `peq-mobile.pen`（预留）
- `peq-pc.pen`（预留）

## 推荐流程

1. 优先打开现有固定文件进行迭代，不新建同类文件。
2. 在 Pencil 中完成修改后直接覆盖保存。
3. 只有结构性大改（例如完全重做）才创建归档副本。
4. 目录约定不变：
   - Navidrome：`docs/designs/pencil/navidrome/`
   - PEQ：`docs/designs/pencil/peq/`

## 当前 Navidrome 稿件说明

- 移动端文件：`docs/designs/pencil/navidrome/navidrome-mobile.pen`
- 桌面端文件：`docs/designs/pencil/navidrome/navidrome-pc.pen`

### 移动端页面

- `01 Login`
- `02 Home`
- `03 Library`
- `04 Search`
- `05 Player`
- `06 Playlists`
- `07 Downloads`
- `08 Settings`

### 桌面端页面

- `01 登录页`
- `02 首页`
- `03 音乐库`
- `04 搜索`
- `05 播放器`
- `06 设置`

### 桌面端组件化说明

- 文件：`docs/designs/pencil/navidrome/navidrome-pc.pen`
- 设计变量：颜色与字体变量已集中在 `variables`
- 复用组件（9 个）：
  - `cmp_primary_button`
  - `cmp_input_field`
  - `cmp_nav_default`
  - `cmp_sidebar`
  - `cmp_stat_card`
  - `cmp_list_row`
  - `cmp_section_card`
  - `cmp_search_input`
  - `cmp_progress_card`
- 组件实例引用：33 处（便于后续统一改样式）
- 左侧导航：首页/音乐库/搜索/设置统一复用 `cmp_sidebar`，仅通过 `descendants` 切换激活项

### 归档说明

- 历史文件已移到：`docs/designs/pencil/navidrome/archive/`
