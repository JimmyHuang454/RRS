quit(){
  echo $1
  exit 1
}

download_lastest_RRS_to() {
  DOWNLOAD_LINK="https://github.com/JimmyHuang454/RRS/releases/latest/download/RRS_Linux.zip"
  echo "Downloading from: $DOWNLOAD_LINK"
  if ! curl -R -H 'Cache-Control: no-cache' -o "$1"  "$DOWNLOAD_LINK"; then
    quit 'error: Download failed! Please check your network or try again.'
  fi
}

decompression() {
  if ! unzip -q "$1" -d ./runtime/ ; then
    quit 'error: decompression failed.'
  fi
}

SAVE_PATH="./step1.zip"
download_lastest_RRS_to $SAVE_PATH
decompression $SAVE_PATH
