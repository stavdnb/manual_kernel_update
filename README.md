## Homework-01

Для выполнения данного ДЗ в файле centos.json была добавлена строка 
``` "headless": "true"   ``` - которая позволяет запускать машину в Virtualbox без использования GUI

С помощью строки ```. config.vm.synced_folder "~/shared_os" , "/vagrant" ``` в файле Vagrantfile мы пробрасываем локальную папку ~/shared_os внутрь ВМ

При публикации собранного образа в Vagrant Cloud столкнулся с ошибкой SSL , решается следующим образом : 

В файле ``` /opt/vagrant/embedded/lib/ruby/2.6.0/openssl/ssl.rb ``` необходимо привести строку к следующему виду ``` TLSv1: OpenSSL::SSL::TLS1_2_VERSION ```

Таким образом мы включаем поддержку TLS 1.2 во встроенном окружении Ruby



## Homework-03
Перед началом работы поставьте пакет xfsdump - он будет необходим для снятия копии / тома.
 
 ### Подготовим временный том для / раздела:
pvcreate /dev/sdb

vgcreate vg_root /dev/sdb 

lvcreate -n lv_root -l +100%FREE /dev/vg_root
###  Создадим на нем файловую систему и смонтируем его, чтобы перенести туда данные:
mkfs.xfs /dev/vg_root/lv_root 

mount /dev/vg_root/lv_root /mnt
  
   
 ### Этой командой скопируем все данные с / раздела в /mnt:
[ xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt xfsrestore: Restore Status: SUCCESS
Тут выхлоп большой, но в итоге вы должны увидеть SUCCESS. Проверить что скопировалосб можно командой ls /mnt
  
   
###  Затем переконфигурируем grub для того, чтобы при старте перейти в новый / Сымитируем текущий root -> сделаем в него chroot и обновим grub:
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done [ chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
     
###  Обновим образ initrd. 
[ cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done

###  Ну и для того, чтобы при загрузке был смонтирован нужно root нужно в файле /boot/grub2/grub.cfg заменить rd.lvm.lv=VolGroup00/LogVol00 на rd.lvm.lv=vg_root/lv_root
  
   
### Перезагружаемся успешно с новым рут томом. Убедиться в этом можно посмотрев вывод lsblk:
[ lsblk
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
 sda 8:0
|-sda1 8:1
|-sda2 8:2
`-sda3 8:3
0 0 0 0
40G 0 disk 1M 0 part
1G 0 part /boot 39G 0 part
253:1 0 1.5G 0 lvm [SWAP] 253:2 0 37.5G 0 lvm
|-VolGroup00-LogVol01
`-VolGroup00-LogVol00
sdb 8:16 0
`-vg_root-lv_root 253:0 0 10G 0 lvm /
sdc 8:32 0
sdd 8:48 0
sde 8:64 0
2G 0 disk 1G 0 disk 1G 0 disk
10G 0 disk
  
   
###  Теперь нам нужно изменить размер старой VG и вернуть на него рут. Для этого удаляем старый LV размеров в 40G и создаем новый на 8G:
lvremove /dev/VolGroup00/LogVol00

lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
    
###  Проделываем на нем те же операции, что и в первый раз:
mkfs.xfs /dev/VolGroup00/LogVol00

mount /dev/VolGroup00/LogVol00 /mnt

xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt 

xfsrestore: Restore Status: SUCCESS
   
###  Так же как в первый раз переконфигурируем grub, за исключением правки /etc/grub2/grub.cfg
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done 

chroot /mnt/

grub2-mkconfig -o /boot/grub2/grub.cfg

cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done

### Пока не перезагружаемся и не выходим из под chroot - мы можем заодно перенести /var
  
###   Выделить том под /var в зеркало
 ###   На свободных дисках создаем зеркало:
pvcreate /dev/sdc /dev/sdd 
vgcreate vg_var /dev/sdc /dev/sdd 
vcreate -L 950M -m1 -n lv_var vg_var 
  
 ###  Выделить том под /var в зеркало
  ###  Создаем на нем ФС и перемещаем туда /var: 
  
mkfs.ext4 /dev/vg_var/lv_var

mount /dev/vg_var/lv_var /mnt

cp -aR /var/* /mnt/ # rsync -avHPSAX /var/ /mnt/
###  На всякий случай сохраняем содержимое старого var (или же можно его просто удалить): [ mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
###  Ну и монтируем новый var в каталог /var:
umount /mnt

mount /dev/vg_var/lv_var /var
### Правим fstab для автоматического монтирования /var:
[ echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
  
###   Выделить том под /var
###    После чего можно успешно перезагружаться в новый (уменьшенный root) и удалять временную Volume Group:
lvremove /dev/vg_root/lv_root

vgremove /dev/vg_root V

pvremove /dev/sdb

  
 ###  Выделить том под /home
###  Выделяем том под /home по тому же принципу что делали для /var: [ lvcreate -n LogVol_Home -L 2G /dev/VolGroup00

mkfs.xfs /dev/VolGroup00/LogVol_Home

mount /dev/VolGroup00/LogVol_Home /mnt/ [ cp -aR /home/* /mnt/

rm -rf /home/*

umount /mnt

mount /dev/VolGroup00/LogVol_Home /home/

### Правим fstab для автоматического монтирования /home
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
  
###  /home - сделать том для снапшотов
  Сгенерируем файлы в /home/:
touch /home/file{1..20}
### Снять снапшот:
lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home 

Удалить часть файлов:
rm -f /home/file{11..20}
### Процесс восстановления со снапшота:
umount /home
lvconvert --merge /dev/VolGroup00/home_snap [ mount /home
