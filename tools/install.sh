quit(){
  echo $1
  exit 1
}

download_lastest_RRS_to() {
  DOWNLOAD_LINK="https://github.com/JimmyHuang454/RRS/releases/latest/download/RRS_Linux.zip"
  echo "Downloading from: $DOWNLOAD_LINK"
  if ! curl -R -L -H 'Cache-Control: no-cache' -o "$1"  "$DOWNLOAD_LINK"; then
    quit 'error: Download failed! Please check your network or try again.'
  fi
}

decompression() {
  if ! unzip -q "$1" -d ./runtime/ ; then
    quit 'error: decompression failed.'
  fi
}

run_service() {
    if systemctl start "./runtime/RRS_Linux.exe"; then
      echo 'ok: Start the service.'
    else
      quit 'failed to run service.';
    fi
}

install_startup_service_file() {
  get_current_version
  if [[ "$(echo "${CURRENT_VERSION#v}" | sed 's/-.*//' | awk -F'.' '{print $1}')" -gt "4" ]]; then
    START_COMMAND="/usr/local/bin/v2ray run"
  else
    START_COMMAND="/usr/local/bin/v2ray"
  fi
  install -m 644 "${TMP_DIRECTORY}/systemd/system/v2ray.service" /etc/systemd/system/v2ray.service
  install -m 644 "${TMP_DIRECTORY}/systemd/system/v2ray@.service" /etc/systemd/system/v2ray@.service
  mkdir -p '/etc/systemd/system/v2ray.service.d'
  mkdir -p '/etc/systemd/system/v2ray@.service.d/'
  if [[ -n "$JSONS_PATH" ]]; then
    "rm" -f '/etc/systemd/system/v2ray.service.d/10-donot_touch_single_conf.conf' \
      '/etc/systemd/system/v2ray@.service.d/10-donot_touch_single_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=${START_COMMAND} -confdir $JSONS_PATH" |
      tee '/etc/systemd/system/v2ray.service.d/10-donot_touch_multi_conf.conf' > '/etc/systemd/system/v2ray@.service.d/10-donot_touch_multi_conf.conf'
  else
    "rm" -f '/etc/systemd/system/v2ray.service.d/10-donot_touch_multi_conf.conf' \
      '/etc/systemd/system/v2ray@.service.d/10-donot_touch_multi_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=${START_COMMAND} -config ${JSON_PATH}/config.json" > '/etc/systemd/system/v2ray.service.d/10-donot_touch_single_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=${START_COMMAND} -config ${JSON_PATH}/%i.json" > '/etc/systemd/system/v2ray@.service.d/10-donot_touch_single_conf.conf'
  fi
  echo "info: Systemd service files have been installed successfully!"
  echo "${red}warning: ${green}The following are the actual parameters for the v2ray service startup."
  echo "${red}warning: ${green}Please make sure the configuration file path is correctly set.${reset}"
  systemd_cat_config /etc/systemd/system/v2ray.service
  # shellcheck disable=SC2154
  if [[ x"${check_all_service_files:0:1}" = x'y' ]]; then
    echo
    echo
    systemd_cat_config /etc/systemd/system/v2ray@.service
  fi
  systemctl daemon-reload
  SYSTEMD='1'
}

check_if_running_as_root() {
  # If you want to run as another user, please modify $UID to be owned by this user
  if [[ "$UID" -ne '0' ]]; then
    echo "WARNING: The user currently executing this script is not root. You may encounter the insufficient privilege error."
    read -r -p "Are you sure you want to continue? [y/n] " cont_without_been_root
    if [[ x"${cont_without_been_root:0:1}" = x'y' ]]; then
      echo "Continuing the installation with current user..."
    else
      echo "Not running with root, exiting..."
      exit 1
    fi
  fi
}

check_if_running_as_root
kill -9 $(pgrep -f [RRS_Linux.exe])
cd /usr/bin/
rm -rf ./rrs/
mkdir ./rrs/
cd rrs

SAVE_PATH="./abc.zip"
download_lastest_RRS_to $SAVE_PATH
rm -rf ./runtime/
decompression $SAVE_PATH
rm $SAVE_PATH
fuser -k -n tcp 443
sudo chmod -R 775 .
run_service
