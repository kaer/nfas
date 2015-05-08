#!/bin/bash
set -x

# Script para as inicializações de rede
# Chamada: "/script/network.sh <cmd>"
# <cmd>: --first     durante primeira instalação

#-----------------------------------------------------------------------
# Processa a linha de comando

CMD=$1
# usa as variaveis armazenadas
. /script/info/distro.var

#-----------------------------------------------------------------------
# Cria arquivo  que é executado ao reiniciar a rede
# http://xmodulo.com/how-to-run-startup-script-automatically-after-network-interface-is-up-on-centos.html

if [ "$CMD" == "--first" ]; then
  if [ "$DISTRO_NAME" == "CentOS" ]; then
    # só para "CentOS", deve ser o mesmo para CenOS7, Ubuntu pode ser diferente
    ARQ="/sbin/ifup-local"
    if [ ! -e $ARQ ]; then
      cat <<- EOF > $ARQ
				#!/bin/sh
				if [[ "\$1" == "eth0" ]]; then
				  echo "this part will be executed right after eth0 is up."
				  postfix flush
				  logger -t ifup-local "Postfix flush"
				fi
			EOF
      chmod +x $ARQ
    fi
  fi # CentOS 6
fi # --first

#-----------------------------------------------------------------------

