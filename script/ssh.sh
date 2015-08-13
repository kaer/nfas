#!/bin/bash
set -x

# Script para Configurar SSH e acesso de ROOT
# As perguntas são interativas através de TUI
# Uso: /script/ssh.sh <cmd>
# <cmd>: --first     primeira instalação, não mosta menu
#        <em branco> Mostra menu interativo
#
# * acrescentar certificado publickey (--first)
# * eliminar certificado publickey
# * bloquear acesso de root pelo ssh (--first)
# * bloquear acesso pelo ssh com senha (--first)
# * alterar senha de root
# * (re)configurar portknock (--first)

#-----------------------------------------------------------------------
# Grava Variáveis de configuração
function SaveVars(){
  echo "SSH_=\"$SSH_\""                        2>/dev/null >  $VAR_FILE
  echo "SSH_=\"$SSH_\""                        2>/dev/null >> $VAR_FILE
}

#=======================================================================
# Processa a linha de comando
CMD=$1
# Funções auxiliares
. /script/functions.sh
# Lê dados anteriores se existirem
. /script/info/distro.var
VAR_FILE="/script/info/ssh.var"
[ -e $VAR_FILE ] && . $VAR_FILE

#-----------------------------------------------------------------------
# main()

# somente root pode executar este script
if [ "$(id -u)" != "0" ]; then
  echo "Somente root pode executar este comando"
  exit 255
fi
TITLE="NFAS - Configuração de SSH e acesso de ROOT"
if [ "$CMD" == "--first" ]; then
  # Durante instalação não mostra menus
  # Novo certificado de root
  AskNewKey root /root
  # mensagem para bloqueio de acesso mas tarde
     MSG="\nPara fazer o bloqueio:"
    MSG+="\n  Acesso via SSH por senha"
    MSG+="\n  Acesso via SSH como usuário ROOT"
  MSG+="\n\nutilize o comando \"nfas\" após terminar a instalação"
  MSG+="\ne somente após testar os acessos!!!"
  whiptail --title "$TITLE" --msgbox "$MSG" 13 70
else
  # Loop do Monu principal interativo
  while true; do
    # Mostra Menu
    PASS_AUTH=$(GetConfSpace /etc/ssh/sshd_config PasswordAuthentication)
    if [ "$PASS_AUTH" == "yes" ]; then
      MSG_SSH_SENHA="Bloquear acesso pelo SSH com senha, ATUAL=permitido"
    else
      MSG_SSH_SENHA="Permitir acesso pelo SSH com senha, ATUAL=bloquado"
    fi
    R_LOGIN=$(GetConfSpace /etc/ssh/sshd_config PermitRootLogin)
    if [ "$R_LOGIN" == "yes" ]; then
      MSG_ROOT_SSH="Bloquear acesso de root pelo SSH,   ATUAL=permitido"
    else
      MSG_ROOT_SSH="Permitir acesso de root pelo SSH,   ATUAL=bloquado"
    fi
    MENU_IT=$(whiptail --title "$TITLE" \
        --menu "\nSelecione um comando de reconfiguração:" --fb 18 70 5   \
        "1" "Acrescentar Chave Pública (PublicKey)"  \
        "2" "Remover Chave Pública (PublicKey)"      \
        "3" "$MSG_SSH_SENHA"                     \
        "4" "$MSG_ROOT_SSH"                      \
        "5" "Reconfigurar PortKnock"             \
        3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then
        echo "Seleção cancelada."
        exit 0
    fi
    # Funções que ficam em Procedures
    # Novo certificado de root
    [ "$MENU_IT" == "1" ] && AskNewKey root /root
    # Remove certificado de root
    [ "$MENU_IT" == "2" ] && DeleteKeys root /root

    # altera Acesso com senha
    if [ "$MENU_IT" == "3" ];then
      [ "$PASS_AUTH" == "yes" ] && TMP="no" || TMP="yes"
      EditConfSpace /etc/ssh/sshd_config PasswordAuthentication $TMP
      # Recarrega o SSHD para usar novo paremetro
      service sshd reload
    fi

    # Altera acesso de root
    if [ "$MENU_IT" == "4" ];then
      [ "$R_LOGIN" == "yes" ] && TMP="no" || TMP="yes"
      EditConfSpace /etc/ssh/sshd_config PermitRootLogin $TMP
      # Recarrega o SSHD para usar novo paremetro
      service sshd reload
    fi

    [ "$MENU_IT" == "5" ] && echo "Não implementado"
    # read -p "Enter para continuar..." TMP
  done # loop menu principal
fi # else --first
