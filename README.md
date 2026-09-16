# 🩺 ops-doctor

> **One command. Full server checkup.** No agents. No config. No dependencies.

```bash
curl -fsSL https://raw.githubusercontent.com/tomlen045/ops-doctor/main/ops-doctor.sh | bash
```

Paste that on any Linux server and get an instant health report: **load, memory, disk, inodes, zombies, failed services, OOM history, pending reboots, SSH hardening** — with a 0-100 health score and concrete fix suggestions. Not a wall of raw numbers: every finding tells you *what to do about it*.

## Why

Servers don't fail dramatically — they rot quietly. Disk creeps to 90%, a service dies three weeks ago, OOM started killing things last Tuesday. `ops-doctor` catches all of that in the 5 seconds before your boss asks why the site is down.

The author ran it on his own Mac before publishing. It found real problems. That's the demo.

## Sample output

```
== Disk ==
  [CRIT] disk /data is 93% full — writes will fail soon
  [WARN] disk / is 81% full
  [ OK ] disk usage scan done (alert threshold 80%)

== OOM history ==
  [ OK ] no OOM kills in the last 7 days

==== HEALTH SCORE: 0/100 🚨 UNHEALTHY ====
  critical: 10 · warnings: 1
```

## Features

- **15+ checks**: load, memory/swap, disk space **and inodes**, zombies, failed systemd units, OOM kills, reboot-required, pending updates, SSH hardening (root login / password auth)
- **Health score** 0–100 with exit code (`0` healthy, `1` critical) — drop it straight into cron or CI
- **Markdown report**: `bash ops-doctor.sh --md report.md` — paste into tickets or wikis
- **Zero dependencies**: bash + coreutils. No agent to install, nothing left behind
- **Private by design**: runs locally, sends nothing anywhere

## Usage

```bash
bash ops-doctor.sh                 # colored report + health score
bash ops-doctor.sh --md report.md  # also write a markdown report
echo $?                            # 0 = healthy, 1 = critical findings
```

### Cron example — weekly checkup emailed to you

```bash
0 9 * * 1 bash /opt/ops-doctor.sh --md /tmp/report.md && mail -s "weekly server checkup" you@company.com < /tmp/report.md
```

## Compatibility

Linux (primary — designed for servers) · macOS (partial, core checks only)

中文说明：一条命令给 Linux 服务器做全套体检，输出健康分和修复建议。纯本地运行，零依赖，不上传任何数据。

## License

MIT

---

## 🫰 关注「小薅薅」· 每天发现一个宝藏工具

> **小薅薅** — 年轻人的赛博工具箱。每天为你发现一个好玩、实用、开源的小工具，帮你节省 1 小时探索时间。
>
> 📱 **微信搜索「小薅薅」** 或扫描下方二维码关注
>
> 后台回复关键词获取：
> - 回复 **「工具」** → 获取全部工具合集（离线可用）
> - 回复 **「运维」** → 获取运维/安全资源包
> - 回复 **「加群」** → 加入工具交流群

<div align="center">

| 🎯 更多作品 | 描述 | Stars |
|:---|:---|:---|
| [ops-skills](https://github.com/tomlen045/ops-skills) | 10个AI运维技能包，让Claude Code变成SRE专家 | [⭐ 新项目](https://github.com/tomlen045/ops-skills) |
| [shellmbti](https://github.com/tomlen045/shellmbti) | 你的终端历史暴露了你是谁——Shell MBTI人格测试 | [⭐ 病毒传播](https://github.com/tomlen045/shellmbti) |
| [naicha-mbti](https://github.com/tomlen045/naicha-mbti) | 8道题测出你的奶茶人格，生成分享卡片 | [🧋 爆款](https://github.com/tomlen045/naicha-mbti) |
| [fafa-generator](https://github.com/tomlen045/fafa-generator) | 发疯文学生成器——一键生成发疯文案+卡片 | [🔥 热门](https://github.com/tomlen045/fafa-generator) |
| [life-progress](https://github.com/tomlen045/life-progress) | 人生进度条——把你的时间摆在眼前 | [⏳ 走心](https://github.com/tomlen045/life-progress) |

</div>

<div align="center">

**觉得有用？给个 ⭐ 让更多人看到 → [GitHub](https://github.com/tomlen045) | [Gitee](https://gitee.com/tomlen)**

</div>
