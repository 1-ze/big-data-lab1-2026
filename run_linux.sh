#!/usr/bin/env bash
# Refuse existing exercise paths before changing files.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$ROOT/results"
exec > >(tee "$ROOT/results/linux.log") 2>&1
for p in /tmp/a /tmp/a1 /tmp/test /tmp/hello /usr/bashrc1 /usr/test /usr/test2 /test /test.tar.gz; do
    if [[ -e "$p" || -L "$p" ]]; then printf 'PREEXISTING_PATH_STOP %s\n' "$p"; exit 2; fi
done
sudo -n true
set -x
date --iso-8601=seconds
whoami
cd /usr/local; pwd
cd ..; pwd
cd; pwd
ls /usr
cd /tmp
mkdir a; ls /tmp
mkdir -p a1/a2/a3/a4; find /tmp/a1 -type d
rmdir /tmp/a
rmdir -p a1/a2/a3/a4
ls /tmp
sudo -n cp "$HOME/.bashrc" /usr/bashrc1
mkdir /tmp/test
sudo -n cp -r /tmp/test /usr/test
sudo -n mv /usr/bashrc1 /usr/test/
sudo -n mv /usr/test /usr/test2
sudo -n rm /usr/test2/bashrc1
sudo -n rm -r /usr/test2
cat "$HOME/.bashrc"
tac "$HOME/.bashrc"
more "$HOME/.bashrc" < /dev/null
head -n 20 "$HOME/.bashrc"
head -n -50 "$HOME/.bashrc"
tail -n 20 "$HOME/.bashrc"
tail -n +51 "$HOME/.bashrc"
touch /tmp/hello
stat /tmp/hello
touch -d '5 days ago' /tmp/hello
stat /tmp/hello
sudo -n chown root /tmp/hello
ls -l /tmp/hello
find "$HOME" -name .bashrc -type f
sudo -n mkdir /test
sudo -n tar -czf /test.tar.gz -C / test
sudo -n tar -xzf /test.tar.gz -C /tmp
tar -tzf /test.tar.gz
grep -n 'examples' "$HOME/.bashrc" || [[ $? == 1 ]]
printf 'LINUX_ALL_DONE\n'
