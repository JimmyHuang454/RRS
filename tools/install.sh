download_lastest_RRS_to() {
  # DOWNLOAD_LINK="https://github.com/JimmyHuang454/RRS/releases/download/latest/RRS_Linux.exe"
  DOWNLOAD_LINK="https://github.com/2dust/v2rayN/releases/download/6.27/v2rayN-32.zip"
  echo "Downloading archive: $DOWNLOAD_LINK"
  if ! curl -R -H 'Cache-Control: no-cache' -o "$1"  "$DOWNLOAD_LINK"; then
    echo 'error: Download failed! Please check your network or try again.'
    exit 1
  fi
}

decompression() {
  SAVED_PATH="./step2/"
  if ! unzip -q "$1" -d $SAVED_PATH ; then
    echo 'error: decompression failed.'
    "rm" -r "$SAVED_PATH"
    echo "removed: $SAVED_PATH"
    exit 1
  fi
  echo "info: Extract the package to $SAVED_PATH and prepare it for installation."
}

# download_lastest_RRS_to "./files1.zip"
decompression "./step1.zip"
