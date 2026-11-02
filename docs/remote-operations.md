# 远程运维目标

仅在发布或远程运维任务中读取；这些是既有目标记录，不代表已完成预检或取得执行授权。

- `dmit`：Tuneleap Cloud VPS 和私有更新发布主机；既有 `apps/player/scripts/deploy-private-update.sh` 默认发布到 `dmit:/opt/navidrome-cloud/releases`，执行前核对当前脚本与本次目标。
- `himym`：家庭 NAS，运行 `services/nas-agent` 和 Navidrome；Cloud 通过受限私有通路访问 NAS Agent。

同时确认 SSH alias、remote dir、服务和影响范围，先做限定目标的只读预检；部署、安装、真实账号/数据库/媒体操作须有相应授权。保持 Cloud 与 NAS Agent 的职责、凭据和数据边界，不记录秘密值，不因部署脚本存在而自动运行。
