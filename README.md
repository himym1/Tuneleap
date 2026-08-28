# 音跃

私人音乐产品仓。用户看见的名字是 **音跃**，英文 **Tuneleap**。仓库是 [`himym1/Tuneleap`](https://github.com/himym1/Tuneleap)。一个产品、三个产物。

Navidrome 只是曲库后端，不是本仓的名字。

## 三个产物

| 目录 | 产物 | 运行位置 | 职责 |
|---|---|---|---|
| [`apps/player`](apps/player) | Flutter 客户端 | 用户设备 | 播放、曲库、搜索 UI、推荐展示、更新安装 |
| [`services/cloud`](services/cloud) | FastAPI 控制面 | DMIT 公网 | 搜索、播放 URL/封面/歌词、推荐、账号、私有更新 |
| [`services/nas-agent`](services/nas-agent) | FastAPI Agent | himym NAS 局域网 | 导入、删除、扫描、曲库体检、曲库身份 |

生产部署名暂时沿用 `navidrome-cloud`、`navidrome-nas-agent`。这一轮只合源码，不改镜像、compose 服务名、SSH 路径和 `https://player.himym.us.ci`。

## 信任边界

```text
App  ──Bearer──►  cloud（公网，Postgres，不挂音乐盘，不打开 navidrome.db）
App  ──LAN Key─►  nas-agent（写 MUSIC_DIR，读/改 navidrome.db）
App  ──Subsonic─► Navidrome
cloud ─只读 identities─► nas-agent
```

合仓不是合进程。Cloud 和 NAS Agent 仍是两个容器、两套密钥。

## 给 AI

先读 [`AGENTS.md`](AGENTS.md) 和 [`docs/architecture.md`](docs/architecture.md)。改 API 或歌曲身份算法时，同时看 `apps/player`、`services/cloud`、`services/nas-agent` 和 [`contracts/`](contracts)。

## 本地命令

```bash
# 播放器
make player-deps
make player-analyze
make player-test

# 服务（各自的 .env，互不共用）
make cloud-up
make nas-agent-test
```

发布 App：`make android`、`make macos`、`make publish`。步骤见 [`apps/player/docs/release.md`](apps/player/docs/release.md)。

## 克隆

```bash
git clone https://github.com/himym1/Tuneleap.git
cd Tuneleap
```

## 旧仓库

历史在 subtree 里。原先三个 GitHub 仓仍可独立存在；新工作以本仓为准。
