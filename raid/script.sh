#!/bin/bash
mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh
yum install -y mdadm smartmontools hdparm gdisk nano mc


mdadm --zero-superblock --force /dev/sd{b,c,d,e}

#Создаем массив RAID10
mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}

#Сохраняем конфиг RAID
echo "DEVICE partitions" > /etc/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm.conf

#Создаем GPT раздел
parted -s /dev/md0 mklabel gpt

#Создаем разделы
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%


#Форматируем разделы и монтируем их

for i in $(seq 1 5); do
  mkfs.ext4 /dev/md0p$i;
  mkdir -p /raid/p$i;
  echo "$(blkid -o export /dev/md0p$i | grep ^UUID=) /raid/p$i                        ext4     rw,exec,auto,nouser        1 2" >> /etc/fstab
done
mount -a

#Обновляем загрузчик
mv -f /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.old
dracut -f /boot/initramfs-$(uname -r).img
