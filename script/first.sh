#!/bin/bash
set -x

# Script de inicialização geral, chamadao pelo boot.sh

echo "Parabéns, você está rotando o /script/first.sh"

# Diretório de informações coletadas
mkdir -p /script/info

# Primeiro verifica se a Distribuição é compatível,
# executa o script e importa as variáveis resultantes
/script/distro.sh
. /script/info/distro.var
if [ "$DISTRO_OK" != "Y" ]; then
  MSG="A distribuição encontrada é \"$DISTRO_NAME\" versão \"$DISTRO_VERSION\"\n"
  MSG="$MSG""As vesrões compatíveis são: \"$DISTRO_LIST\"\n\n   Abortando instalação..."
  whiptail --title "Instalação NFAS" --msgbox "\"$MSG"\" 11 60
  exit 1
fi

# Perguntas de configuração antes de começar:
# alterar hostname
# (?)

# atualiza todo o sistema
yum -y update
# Repositório auxiliar: https://fedoraproject.org/wiki/EPEL
yum -y install epel-release
# Instalar pacotes extra
yum -y man nano mcedit

# Altera o /etc/rc.d/rc.local para chamar o /script/autostart.sh
cat /etc/rc.d/rc.local | grep "autostart.sh"
if [ $? -ne 0 ]; then
  echo -e "\n# NFAS: executa scripts de inicialização\n/script/autostart.sh\n" >> /etc/rc.d/rc.local
fi

# Roda as configuraçãoes próprias para o VirtualBox
/script/virtualbox.sh

# ===== FIM do first.sh =====
# => executa o /script/autostart.sh para iniciar
/script/autostart.sh

