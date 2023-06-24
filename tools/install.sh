download_lastest_RRS_to() {
  DOWNLOAD_LINK="https://github.com/JimmyHuang454/RRS/releases/download/latest/RRS_Linux.zip"
  echo "Downloading from: $DOWNLOAD_LINK"
  if ! curl -R -H 'Cache-Control: no-cache' -o "$1"  "$DOWNLOAD_LINK"; then
    echo 'error: Download failed! Please check your network or try again.'
    exit 1
  fi
}

decompression() {
  SAVED_PATH="./step2/"
  if ! unzip -q "$1" -d $SAVED_PATH ; then
    echo 'error: decompression failed.'
    exit 1
  fi
}

download_lastest_RRS_to "./step1.zip"
decompression "./step1.zip"
