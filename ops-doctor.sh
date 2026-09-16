#!/usr/bin/env bash
# ops-doctor v0.1 — one-command server health checkup
# Usage:  bash ops-doctor.sh            (pretty output + health score)
#         bash ops-doctor.sh --md out.md (also write a markdown report)
# No agents, no config, no dependencies beyond bash+coreutils. Linux-first, macOS partial.
set -u

C_OK="\033[32m"; C_WARN="\033[33m"; C_CRIT="\033[31m"; C_INFO="\033[36m"; C_B="\033[1m"; C_0="\033[0m"
MD=""; [[ "${1:-}" == "--md" && "${2:-}" != "" ]] && MD="$2"
CRIT=0; WARN=0
MDL=()

p_ok()  { echo -e "  ${C_OK}[ OK ]${C_0} $1";  [[ -n "$MD" ]] && MDL+=("- ✅ $1"); }
p_warn(){ WARN=$((WARN+1)); echo -e "  ${C_WARN}[WARN]${C_0} $1"; [[ -n "$MD" ]] && MDL+=("- ⚠️ $1"); }
p_crit(){ CRIT=$((CRIT+1)); echo -e "  ${C_CRIT}[CRIT]${C_0} $1"; [[ -n "$MD" ]] && MDL+=("- ❌ $1"); }
p_skip(){ echo -e "  ${C_INFO}[SKIP]${C_0} $1"; [[ -n "$MD" ]] && MDL+=("- ➖ $1"); }
p_info(){ echo -e "  ${C_INFO}[info]${C_0} $1"; [[ -n "$MD" ]] && MDL+=("- ℹ️ $1"); }
section(){ echo -e "\n${C_B}== $1 ==${C_0}"; [[ -n "$MD" ]] && MDL+=("" "### $1"); }

OS="$(uname -s)"
IS_LINUX=0; [[ "$OS" == "Linux" ]] && IS_LINUX=1

section "System"
echo -e "  host: $(uname -srm)"
UPD=""
if [[ -f /proc/uptime ]]; then
  UPD=$(( $(cut -d. -f1 /proc/uptime) / 86400 ))
  p_ok "uptime: ${UPD} days"
  if [[ "$UPD" -gt 365 ]]; then p_warn "uptime ${UPD} days — kernel likely misses security patches, plan a reboot window"; fi
else
  p_skip "uptime details (non-Linux)"
fi

# ---- Load ----
section "Load"
if [[ -f /proc/loadavg ]]; then
  LOAD=$(awk '{print $1}' /proc/loadavg)
  CORES=$(nproc 2>/dev/null || echo 1)
  if awk "BEGIN{exit !($LOAD > $CORES)}"; then p_crit "load average ${LOAD} > cores (${CORES}) — system is saturated"
  elif awk "BEGIN{exit !($LOAD > $CORES*0.7)}"; then p_warn "load average ${LOAD} is >70% of ${CORES} cores"
  else p_ok "load average ${LOAD} on ${CORES} cores"; fi
else
  p_skip "load average (non-Linux)"
fi

# ---- Memory ----
section "Memory"
if [[ -f /proc/meminfo ]]; then
  TOTAL=$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo)
  AVAIL=$(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo)
  USED=$((TOTAL-AVAIL)); PCT=$(( USED*100/TOTAL ))
  if [[ $PCT -ge 90 ]]; then p_crit "memory ${PCT}% used (${USED}MB/${TOTAL}MB) — OOM risk"
  elif [[ $PCT -ge 80 ]]; then p_warn "memory ${PCT}% used (${USED}MB/${TOTAL}MB)"
  else p_ok "memory ${PCT}% used (${USED}MB/${TOTAL}MB)"; fi
  SW_T=$(awk '/^SwapTotal/{print int($2/1024)}' /proc/meminfo); SW_F=$(awk '/^SwapFree/{print int($2/1024)}' /proc/meminfo)
  if [[ "${SW_T:-0}" -gt 0 ]]; then SW_P=$(( (SW_T-SW_F)*100/SW_T ))
    if [[ $SW_P -ge 50 ]]; then p_warn "swap ${SW_P}% used — host is under real memory pressure"; fi
  fi
else
  p_skip "memory breakdown (non-Linux)"
fi

# ---- Disk & inodes ----
section "Disk"
while read -r pct mount; do
  if [[ $pct -ge 90 ]]; then p_crit "disk ${mount} is ${pct}% full — writes will fail soon"
  elif [[ $pct -ge 80 ]]; then p_warn "disk ${mount} is ${pct}% full"; fi
done < <(df -P 2>/dev/null | awk 'NR>1 && $6 !~ /^(\/system|\/boot\/efi)$/ && $5 ~ /%/ {gsub(/%/,"",$5); print $5, $6}')
p_ok "disk usage scan done (alert threshold 80%)"
if [[ $IS_LINUX -eq 1 ]] && df -Pi >/dev/null 2>&1; then
  while read -r pct mount; do
    [[ $pct -ge 90 ]] && p_crit "inodes ${mount} at ${pct}% — 'disk not full' but writes WILL fail"
  done < <(df -Pi 2>/dev/null | awk 'NR>1 && $5 ~ /%/ && $6 !~ /^\/system/ {gsub(/%/,"",$5); print $5, $6}')
  p_ok "inode scan done"
fi

# ---- Processes ----
section "Processes"
Z=$(ps axo stat= 2>/dev/null | grep -c '^Z' || true)
if [[ "${Z:-0}" -gt 10 ]]; then p_warn "${Z} zombie processes — find the parent that is not reaping children"; 
elif [[ "${Z:-0}" -gt 0 ]]; then p_ok "${Z} zombie process(es) (harmless below 10)"; else p_ok "no zombie processes"; fi
p_info "top memory consumers:"
ps axo pmem=,comm= 2>/dev/null | sort -rn | head -3 | while read -r pmem comm; do
  echo -e "        ${pmem}%  ${comm}"
done

# ---- Services (systemd) ----
section "Services"
if command -v systemctl >/dev/null 2>&1; then
  FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | grep -c '\.service' || true)
  if [[ "${FAILED:-0}" -gt 0 ]]; then
    p_crit "${FAILED} systemd unit(s) failed — run: systemctl --failed"
    systemctl --failed --no-legend --plain 2>/dev/null | head -5 | while read -r unit rest; do echo -e "        • $unit"; done
  else p_ok "no failed systemd units"; fi
else
  p_skip "systemd not present"
fi

# ---- OOM history ----
section "OOM history"
OOMHITS=""
if command -v journalctl >/dev/null 2>&1; then
  OOMHITS=$(journalctl -k --since "7 days ago" 2>/dev/null | grep -ci "out of memory" || true)
elif command -v dmesg >/dev/null 2>&1; then
  OOMHITS=$(dmesg 2>/dev/null | grep -ci "out of memory" || true)
fi
if [[ "${OOMHITS:-}" != "" ]]; then
  if [[ $OOMHITS -gt 0 ]]; then p_crit "kernel killed processes (OOM) ${OOMHITS} time(s) in the last 7 days — memory is too small for the workload"
  else p_ok "no OOM kills in the last 7 days"; fi
else p_skip "kernel log not readable (try sudo)"; fi

# ---- Reboot required ----
section "Updates"
if [[ -f /var/run/reboot-required ]]; then p_warn "reboot required to apply kernel/security updates"; else [[ $IS_LINUX -eq 1 ]] && p_ok "no reboot flag set"; fi
if command -v apt-get >/dev/null 2>&1; then
  N=$(apt-get -s -o Debug::NoLocking= upgrade 2>/dev/null | grep -c '^Inst' || true)
  p_info "${N:-0} packages have available updates"
elif command -v dnf >/dev/null 2>&1; then
  N=$(dnf -q check-update 2>/dev/null | grep -c . || true)
  p_info "${N:-0} packages have available updates"
fi

# ---- SSH hardening ----
section "SSH hardening"
SSHD_CONF=""
for f in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do [[ -f "$f" ]] && SSHD_CONF="$SSHD_CONF $f"; done
if [[ -n "$SSHD_CONF" ]]; then
  if grep -hisE '^\s*PermitRootLogin\s+yes' $SSHD_CONF >/dev/null 2>&1; then p_warn "SSH allows direct root login — set PermitRootLogin prohibit-password"; fi
  if grep -hisE '^\s*PasswordAuthentication\s+yes' $SSHD_CONF >/dev/null 2>&1; then p_warn "SSH allows password auth — bots WILL brute-force it; set PasswordAuthentication no"; fi
  p_ok "sshd_config scan done"
else p_skip "no sshd_config found (no SSH server?)"; fi

# ---- Summary ----
SCORE=$((100 - CRIT*12 - WARN*4)); [[ $SCORE -lt 0 ]] && SCORE=0
if   [[ $SCORE -ge 90 ]]; then GRADE="🩺 HEALTHY"; GC=$C_OK
elif [[ $SCORE -ge 70 ]]; then GRADE="🩹 NEEDS ATTENTION"; GC=$C_WARN
else GRADE="🚨 UNHEALTHY"; GC=$C_CRIT; fi

echo -e "\n${C_B}==== HEALTH SCORE: ${GC}${SCORE}/100 ${GRADE}${C_0} ===="
echo -e "  critical: ${C_CRIT}${CRIT}${C_0} · warnings: ${C_WARN}${WARN}${C_0}"

if [[ -n "$MD" ]]; then
  { echo "# ops-doctor report — $(date '+%F %T')"
    echo ""
    echo "**Health score: ${SCORE}/100** — critical: ${CRIT}, warnings: ${WARN}"
    for l in "${MDL[@]}"; do echo "$l"; done
  } > "$MD"
  echo "markdown report written: $MD"
fi
exit $(( CRIT > 0 ? 1 : 0 ))
