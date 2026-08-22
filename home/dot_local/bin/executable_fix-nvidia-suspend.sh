#!/bin/bash

# NVIDIA Suspend Fixer for Pop!_OS
# Checks kernel parameters and systemd services for RTX/NVIDIA cards

BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

echo -e "${BOLD}Starting NVIDIA Suspend Diagnostic...${NC}"

# 1. Check for NVIDIA GPU
if ! lspci | grep -i nvidia >/dev/null; then
  echo -e "${RED}[!] No NVIDIA GPU detected via lspci.${NC}"
else
  echo -e "${GREEN}[✓] NVIDIA GPU detected.${NC}"
fi

# 2. Check Kernel Parameter
PARAM_CHECK=$(grep -r "NVreg_PreserveVideoMemoryAllocations=1" /etc/modprobe.d/ 2>/dev/null)
if [ -z "$PARAM_CHECK" ]; then
  echo -e "${YELLOW}[!] Kernel parameter 'NVreg_PreserveVideoMemoryAllocations=1' NOT found in /etc/modprobe.d/${NC}"
  NEEDS_FIX=true
else
  echo -e "${GREEN}[✓] Kernel parameter preservation is configured.${NC}"
fi

# 3. Check Systemd Services
SERVICES=("nvidia-suspend.service" "nvidia-hibernate.service" "nvidia-resume.service")
MISSING_SERVICES=()

for svc in "${SERVICES[@]}"; do
  if ! systemctl is-enabled "$svc" >/dev/null 2>&1; then
    MISSING_SERVICES+=("$svc")
  fi
done

if [ ${#MISSING_SERVICES[@]} -gt 0 ]; then
  echo -e "${YELLOW}[!] The following services are DISABLED: ${MISSING_SERVICES[*]}${NC}"
  NEEDS_FIX=true
else
  echo -e "${GREEN}[✓] All NVIDIA suspend services are enabled.${NC}"
fi

# 4. Prompt for Action
if [ "$NEEDS_FIX" = true ]; then
  echo -e "\n${BOLD}Recommendation:${NC} Enable NVIDIA preservation services and/or fix kernel parameters."
  read -p "Apply fixes now? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Applying fixes...${NC}"

    # Add kernel param if missing
    if [ -z "$PARAM_CHECK" ]; then
      echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee /etc/modprobe.d/nvidia-suspend-fix.conf
    fi

    # Enable services
    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

    echo -e "${GREEN}Done! Please reboot for kernel changes to take effect, or try a suspend now.${NC}"
  else
    echo -e "${NC}Modification cancelled.${NC}"
  fi
else
  echo -e "\n${GREEN}${BOLD}System looks healthy! No fixes required.${NC}"
fi
