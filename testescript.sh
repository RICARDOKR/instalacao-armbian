#######################################################################
#######################################################################
##                                                                   ##
## THIS SCRIPT SHOULD ONLY BE RUN ON A TANIX TX3 BOX RUNNING ARMBIAN ##
##                                                                   ##
#######################################################################
#######################################################################
set -o errexit  # Exit script when a command exits with non-zero status
set -o errtrace # Exit on error inside any functions or sub-shells
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# GLOBALS
# ==============================================================================
readonly HOSTNAME="homeassistant"

readonly REQUIREMENTS=(
  apparmor-utils
  apt-transport-https
  avahi-daemon
  ca-certificates
  curl
  dbus
  jq
  network-manager
  socat
  software-properties-common
)

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Ensures the hostname of the Pi is correct.
# ------------------------------------------------------------------------------
update_hostname() {
  old_hostname=$(< /etc/hostname)
  if [[ "${old_hostname}" != "${HOSTNAME}" ]]; then
    sed -i "s/${old_hostname}/${HOSTNAME}/g" /etc/hostname
    sed -i "s/${old_hostname}/${HOSTNAME}/g" /etc/hosts
    hostname "${HOSTNAME}"
    echo ""
    echo "O nome do host será alterado na próxima reinicialização: ${HOSTNAME}"
    echo ""
  fi
}

# ------------------------------------------------------------------------------
# Installs all required software packages and tools
# ------------------------------------------------------------------------------
install_requirements() {
  echo ""
  echo "Atualizando APT packages list..."
  echo ""
  apt-get --allow-releaseinfo-change update
  apt-get install software-properties-common
  apt-get update
  echo ""
  echo "Certifique-se de que todos os requisitos estejam instalados..."
  echo ""
  apt-get install -y "${REQUIREMENTS[@]}"
}

# ------------------------------------------------------------------------------
# Installs the Docker engine
# ------------------------------------------------------------------------------
install_docker() {
  echo ""
  echo "A instalar Docker..."
  echo ""
  curl -fsSL https://get.docker.com | sh
}

# ------------------------------------------------------------------------------
# Installs and starts Hass.io
# ------------------------------------------------------------------------------
install_hassio() {
  echo ""
  echo "A instalar o Home Assistant..."
  echo ""
  apt-get update
  apt-get install udisks2 wget -y
  wget https://github.com/home-assistant/os-agent/releases/download/1.4.1/os-agent_1.4.1_linux_aarch64.deb
  sudo dpkg -i os-agent_1.4.1_linux_aarch64.deb
  wget https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb
  sudo dpkg -i homeassistant-supervised.deb
}

# ------------------------------------------------------------------------------
# Configure network-manager to disable random MAC-address on Wi-Fi
# ------------------------------------------------------------------------------
config_network_manager() {
  {
    echo -e "\n[device]";
    echo "wifi.scan-rand-mac-address=no";
    echo -e "\n[connection]";
    echo "wifi.clone-mac-address=preserve";
  } >> "/etc/NetworkManager/NetworkManager.conf"
}

# ------------------------------------------------------------------------------
# Upgrade final
# ------------------------------------------------------------------------------
upgrade_final() {
  echo ""
  echo "Upgrade..."
  echo ""
  sudo apt update
  sudo apt upgrade -y
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
  # Are we root?
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Please try again after running:"
    echo "  sudo su"
    exit 1
  fi

  # Install ALL THE THINGS!
  update_hostname
  install_requirements
  config_network_manager
  install_docker
  install_hassio
  upgrade_final

  # Friendly closing message
  ip_addr=$(hostname -I | cut -d ' ' -f1)
  echo "======================================================================="
  echo "Hass.io está agora a instalar o Home Assistant."
  echo "Este processo demora a volta de  20 minutes. Abre o seguinte link:"
  echo "http://${HOSTNAME}.local:8123/ no teu browser"
  echo "para carregar o home assistant."
  echo "Se o link acima não funcionar, tenta o seguinte link http://${ip_addr}:8123/"
  echo "Aproveita o teu home assistant :)"

  exit 0
}
main
