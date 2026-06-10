# hy2-on-demand

按需自建的 [Hysteria 2](https://github.com/apernet/hysteria) 代理服务器，自动通过 UPnP
进行端口映射，并生成可直接导入 Hysteria 2 客户端的链接与二维码。一条命令即可启动，运行在
`screen` 会话中，**无需 root 权限**。

把它装在一台位于支持 UPnP 的家用路由器后面的 Debian/Ubuntu 机器上。运行 `./start-hy2`，
它会在路由器上打开一个随机的公网端口，使用一次性的临时凭据启动 Hysteria 2 服务器，并打印出
`hysteria2://` 链接和一个终端二维码，你可以直接用任意支持 Hysteria 2 的客户端（iOS/Android 均可）扫码导入。停止时，所有内容
——端口映射、服务器、证书和凭据——都会被拆除并彻底清除。

> ⚠️ **前提条件：你家路由器的 WAN 口必须拥有真实的公网 IP 地址。**
> 这是本工具能用的根本前提。如果你的宽带处于运营商级 NAT（CGNAT）之后，UPnP 打开的端口
> 无法从外部访问，客户端也就连不上。自查方法：在路由器后台查看 WAN 口 IP，并与
> <https://ifconfig.me> 显示的 IP 对比——若两者一致，说明你有公网 IP；若不一致（路由器 WAN
> 是 `100.64.x.x`、`10.x.x.x` 等内网段），通常就是 CGNAT，本工具无法使用。

## 工作原理

**启动**时它会：

1. 在 `30000–65535` 之间随机选取一个 UDP 端口；
2. 生成一张全新的自签名 ECDSA TLS 证书和一个随机密码；
3. 在路由器上打开 UPnP 端口映射（`公网:端口 → 本机:端口`，UDP）；
4. 启动 Hysteria 2 服务器（使用 HTTP 伪装作为流量掩护）；
5. 打印连接链接 + 二维码，然后在前台运行。

**停止**时（按 Ctrl-C，或在另一个终端运行 `./start-hy2 stop`），它会移除 UPnP 映射、
停止服务器，并删除证书/密钥/配置/凭据。每次会话之间没有任何东西可以复用——每次启动都是
全新的端口、密码和证书。

## 环境要求

- Debian/Ubuntu 主机（x86_64 / arm64），位于已启用 **UPnP IGD** 的路由器后面；
- 需要 `curl`、`openssl`、`screen`，以及 `apt-get` + `dpkg-deb`（`install.sh` 用它们在
  无需 root 的情况下获取 `upnpc`/`qrencode`）；
- 路由器需拥有**真实的公网 IP**（运营商级 NAT/CGNAT 下 UPnP 端口转发无法生效）。

## 安装

```bash
git clone https://github.com/AddictedCoins/hy2-on-demand.git
cd hy2-on-demand
./install.sh          # 将 hysteria + upnpc + qrencode 下载到 ./bin 和 ./local
```

`install.sh` 会下载最新版的 Hysteria 2，并把 `upnpc`/`qrencode` 从 `.deb` 软件包中解压到
本地文件夹——不会向系统安装任何软件包。

## 使用

```bash
screen -S hy2 ./start-hy2   # 启动；打印链接 + 二维码
#   Ctrl-A 然后按 D          分离 screen 会话（让它在后台继续运行）

./start-hy2 status          # 查看状态 + 当前链接/二维码
./start-hy2 link            # 仅重新打印链接/二维码
./start-hy2 stop            # 停止 + 移除 UPnP 映射 + 清除会话文件
./start-hy2 restart         # 先停止再启动（全新端口/密码/证书）
```

导入：在任意支持 Hysteria 2 的客户端（iOS / Android 均可）中粘贴 `hysteria2://…` 链接，
或扫描终端打印的二维码。链接中已设置 `insecure=1`（自签名证书所必需）。

## 节点备注名

每次启动时，脚本会提示你输入**节点备注名**（即客户端里显示的名称）；直接按回车即使用默认值
`hy2-upnp`。备注名按以下优先级解析：

1. 环境变量 `NODE_NAME`（若已设置）；
2. 脚本同目录下的 `node_name` 文件（取第一行）——想固定一个名字、不再每次询问时很方便；
3. 交互式提示（回车默认 `hy2-upnp`）。

例如，固定备注名且今后不再提示：

```bash
echo "我的节点" > node_name
```

## 其他自定义

编辑 `start-hy2` 顶部的常量：

| 变量                | 用途                                              |
|---------------------|---------------------------------------------------|
| `DEFAULT_NODE_NAME` | 在备注名提示处直接回车时使用的默认值（默认 `hy2-upnp`）。 |
| `SNI`               | 在链路上呈现的 SNI / 伪装域名。                    |
| `MASQ_URL`          | 服务器对探测流量伪装成的网站。                    |
| `UPNP_LEASE`        | UPnP 映射租约时长（秒），运行期间会自动续期。      |

## 说明与注意事项

- **自签名 TLS：** 链接使用 `insecure=1`。流量依然是加密的（QUIC/TLS），只是客户端
  不会针对 CA 校验证书。
- **公网 IP 会变：** 家庭宽带 IP 会轮换。如果旧链接失效，重新启动并重新导入即可。
- **UPnP 无法穿透 CGNAT：** 如果运营商把你放在运营商级 NAT 后面，入站端口转发无法到达你。
- **NAT 回流（Hairpin）：** 在局域网**内部**不一定能测试公网 IP 路径；请用移动网络测试，
  或直接连接局域网 IP 测试。
