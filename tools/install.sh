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

fuser -k -n tcp 443
SAVE_PATH="./abc.zip"
download_lastest_RRS_to $SAVE_PATH
rm -rf ./runtime/
decompression $SAVE_PATH
rm $SAVE_PATH
sudo chmod -R 775 .
nohup ./runtime/RRS_Linux.exe &>/dev/null &

echo 'ok!!!!!!!!!!!'
