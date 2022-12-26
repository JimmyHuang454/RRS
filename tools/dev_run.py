import os
import subprocess

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
BASE_DIR = BASE_DIR.replace('\\', '/')


def DoCMD(cmd, is_wait=True, cwd=None):
    print('\n\n==', cmd, '\n')
    if is_wait:
        subprocess.Popen(cmd, shell=True, cwd=cwd).wait()
    else:
        subprocess.Popen(cmd, shell=True, cwd=cwd)


DoCMD([
    'dart', 'run', './bin/proxy.dart', '-c',
    os.path.dirname(BASE_DIR) + '/bin/config.json', '--ipdb',
    os.path.dirname(BASE_DIR) + '/bin/ip.mmdb'
],
      cwd=os.path.dirname(BASE_DIR))
