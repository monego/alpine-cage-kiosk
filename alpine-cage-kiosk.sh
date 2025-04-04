#!/bin/sh

# https://github.com/cage-kiosk/cage?tab=readme-ov-file

# install alpine x86 iso, add a user that you will use for remote ssh access. When install, select partition to install to and choose /srv

# for the cage script below, change the urls to the tabs you want to open by default

su # become root

apk update
apk upgrade

setup-wayland-base
# note: installs and configures elogind and polkit-elogind

apk add nano firefox cage greetd font-misc-misc font-noto font-dejavu pipewire wireplumber

mkdir -p /home/cage/
cat > /home/cage/cage-launch.sh<< EOF
#!/bin/sh
/usr/libexec/pipewire-launcher &
cage -- firefox 'https://wastalinux.org' 'https://desertblooms.net'
exit 0
EOF

chmod -R 755 /home/cage/

sed -i -e "s@\(^command =\).*@\1 \"cage -s -- /home/cage/cage-launch.sh\"@" /etc/greetd/config.toml

rc-update add greetd
rc-service greetd start

reboot
