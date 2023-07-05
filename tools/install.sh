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
  apt install zip

  if ! unzip -q "$1" -d ./runtime/ ; then
    quit 'error: decompression failed.'
  fi
}

PASSWORD="$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM"
IV="$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM"

fuser -k -n tcp 443
SAVE_PATH="./abc.zip"
download_lastest_RRS_to $SAVE_PATH
rm -rf ./runtime/
decompression $SAVE_PATH
rm $SAVE_PATH
sudo chmod -R 775 .
sed -i "s/123456/$PASSWORD/" ./runtime/config.json
sed -i "s/abcabc/$IV/" ./runtime/config.json
nohup ./runtime/RRS_Linux.exe &>/dev/null &


echo " "
echo "password: $PASSWORD"
echo "random:   $IV"
echo " "
