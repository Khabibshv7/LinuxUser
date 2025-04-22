#!/bin/bash

set -e  # Səhv olduqda skripti dərhal dayandır

# Root yoxlaması
if [ "$EUID" -ne 0 ]; then
  echo "Zəhmət olmasa skripti root olaraq çalışdırın."
  exit 1
fi

# Parametrlərin yoxlanması
if [ $# -ne 3 ]; then
  echo "İstifadə: $0 <istifadəçi_adı> <qrup_adı> <ssh_pub_açarı>"
  exit 1
fi

USERNAME=$1
GROUP=$2
SSHPUB=$3
LOGFILE="/var/log/user_creation.log"

# SSH açarının minimal format yoxlaması
if [[ "$SSHPUB" != ssh-rsa* && "$SSHPUB" != ssh-ed25519* ]]; then
  echo "Xəta: SSH public açarın formatı düzgün deyil."
  exit 1
fi

# Qrup yoxlanır və lazım olsa yaradılır
if getent group "$GROUP" > /dev/null 2>&1; then
  echo "Qrup '$GROUP' mövcuddur."
else
  echo "Qrup '$GROUP' yaradılır..."
  groupadd "$GROUP"
fi

# İstifadəçi yoxlanır və yaradılır
if id "$USERNAME" &>/dev/null; then
  echo "İstifadəçi '$USERNAME' artıq mövcuddur."
  exit 1
else
  useradd -m -g "$GROUP" -s /bin/bash "$USERNAME"
  echo "İstifadəçi '$USERNAME' yaradıldı."
fi

# SSH konfiqurasiya
USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME/.ssh"
echo "$SSHPUB" > "$USER_HOME/.ssh/authorized_keys"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$USERNAME:$GROUP" "$USER_HOME/.ssh"

# SELinux varsa SSH üçün konteksti bərpa et
if command -v restorecon &> /dev/null; then
  restorecon -Rv "$USER_HOME/.ssh"
fi

# İstəyə görə parol təyin edilir (random)
PASSWORD=$(openssl rand -base64 12)
echo "$USERNAME:$PASSWORD" | chpasswd
echo "İstifadəçiyə təsadüfi parol təyin olundu: $PASSWORD"

# Log faylına yazılır
echo "$(date '+%Y-%m-%d %H:%M:%S') - '$USERNAME' adlı istifadəçi yaradıldı, qrup: '$GROUP'" >> "$LOGFILE"

echo "İş tamamlandı. '$USERNAME' adlı istifadəçi uğurla yaradıldı və SSH konfiqurasiyası edildi."
