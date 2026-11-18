#!/usr/bin/bash
set -x
cat /run/secrets/id_rsa.pub >> /home/cm/.ssh/authorized_keys
chown cm /home/cm/.ssh/authorized_keys
cat /run/secrets/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys
chown ubuntu /home/ubuntu/.ssh/authorized_keys
. /etc/os-release
if [ "$ID" = 'centos' ]; then
    VERSION_ID=${VERSION_ID}.stream
elif [ "$ID" = 'rocky' ]; then
    # teuthology suites request rocky by major version (e.g. os_version "10"),
    # but /etc/os-release reports "10.0"; register the major version so the
    # dispatcher can match and lock these nodes.
    VERSION_ID=${VERSION_ID%%.*}
fi
payload="{\"name\": \"$(hostname)\", \"machine_type\": \"testnode\", \"up\": true, \"locked\": false, \"os_type\": \"${ID}\", \"os_version\": \"${VERSION_ID}\"}"
for i in $(seq 1 5); do
    echo "attempt $i"
    curl -v -f -d "$payload" http://paddles:8080/nodes/ && break
    sleep 1
done
mkdir -p /run/sshd
exec /usr/lib/systemd/systemd --system
