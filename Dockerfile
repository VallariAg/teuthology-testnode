FROM quay.io/rockylinux/rockylinux:10
RUN dnf -y update
# Best-effort: on Rocky 10 `rpm --setcaps` can exit non-zero; don't fail the build.
RUN rpm --setcaps shadow-utils 2>/dev/null || true
RUN dnf -y install podman crun --exclude container-selinux && \
    dnf clean all && \
    rm -rf /var/cache /var/log/dnf* /var/log/yum*
RUN useradd podman; \
    echo podman:0:5000 > /etc/subuid; \
    echo podman:0:5000 > /etc/subgid; \
    echo root:0:65535 > /etc/subuid; \
    echo root:0:65535 > /etc/subgid;
RUN mkdir -p /root/.local/share/containers /home/podman/.local/share/containers
VOLUME /var/lib/containers
VOLUME /home/podman/.local/share/containers
VOLUME /root/.local/share/containers
ADD https://raw.githubusercontent.com/containers/image_build/main/podman/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/image_build/main/podman/podman-containers.conf /home/podman/.config/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/image_build/main/podman/podman-containers.conf /root/.config/containers/containers.conf
RUN chown podman:podman -R /home/podman; \
    echo 'podman:podman' | chpasswd
RUN chmod 644 /etc/containers/containers.conf
# Write a known-good storage.conf for nested (podman-in-podman) use. Editing the
# distro default with sed produced invalid TOML on Rocky 10, which broke
# `podman version` and therefore cephadm bootstrap.
RUN cat > /etc/containers/storage.conf <<'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
additionalimagestores = [
  "/var/lib/shared",
]

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
mountopt = "nodev,fsync=0"
EOF
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; \
    touch /var/lib/shared/overlay-images/images.lock; \
    touch /var/lib/shared/overlay-layers/layers.lock; \
    touch /var/lib/shared/vfs-images/images.lock; \
    touch /var/lib/shared/vfs-layers/layers.lock
ENV _CONTAINERS_USERNS_CONFIGURED=""

# `which` is no longer in the Rocky 10 base repos; it ships in EPEL.
RUN dnf -y install epel-release || \
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
RUN dnf -y install \
    which \
    sudo \
    openssh-clients \
    openssh-server \
    hostname \
    python3-pip \
    python3-packaging \
    httpd \
    chrony \
    hostname \
    iproute \
    procps-ng \
    systemd-udev \
    systemd \
    fuse-overlayfs \
    'dnf-command(copr)' \
    lvm2 && \
    echo 'OPTIONS="-x"' > /etc/sysconfig/chronyd && \
    systemctl enable sshd
RUN dnf clean all && \
    rm -rf /var/cache /var/log/dnf* /var/log/yum*
COPY testnode_start.sh /
COPY testnode_stop.sh /
COPY testnode_sudoers /etc/sudoers.d/teuthology
COPY run-fs.service scratch-devs.service /etc/systemd/system/
RUN systemctl enable run-fs scratch-devs
RUN \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' && \
    groupadd sudo && \
    useradd -g sudo cm && \
    mkdir -p /home/cm/.ssh && \
    chmod 700 /home/cm/.ssh && \
    chown -R cm /home/cm && \
    useradd -g sudo ubuntu && \
    mkdir -p /home/ubuntu/.ssh && \
    chmod 700 /home/ubuntu/.ssh && \
    chown -R ubuntu /home/ubuntu
EXPOSE 22
ENTRYPOINT /testnode_start.sh
