#!/bin/bash
# set -x

# === USER MENU ===

# Called by the command: nfas
# Allows access to configurations available after install
# A link was created in /usr/bin/nfas for this script script

# Auxiliary Functions
. /script/functions.sh
# Read prvious config
. /script/info/email.var
# Global variables
APP_NAME=""
TITLE="NFAS - Node.js Full Application Server - Menu"

# Only root can run this script
if [ "$(id -u)" != "0" ]; then
  echo "Only root can run this command"
  exit 255
fi

#-----------------------------------------------------------------------
# Read Application Security and translate to string
# usage: GetAppSecurity <app>
function GetAppSecurity(){
  local HAPP=$1
  # Get all configs and domains for this application
  HAPP_HTTP=""; HAPP_HTTPS=""; HAPP_PORT=""; HAPP_URIS=""
  [ -e /script/info/hap-$HAPP.var ] && . /script/info/hap-$HAPP.var
  [ "$HAPP_HTTP" == "Y" ] && [ "$HAPP_HTTPS" == "N" ] && echo "HTTP only"
  [ "$HAPP_HTTP" == "N" ] && [ "$HAPP_HTTPS" == "Y" ] && echo "HTTPS only"
  [ "$HAPP_HTTP" == "Y" ] && [ "$HAPP_HTTPS" == "Y" ] && echo "HTTP and HTTPS"
}

#-----------------------------------------------------------------------
# Check Application Configuration
# usage: CheckAppConfig <app>
function CheckAppConfig(){
  local MSG OPT PORT
  local HAPP=$1
  # Get all configs and domains for this application
  HAPP_HTTP=""; HAPP_HTTPS=""; HAPP_PORT=""; HAPP_URIS=""
  [ -e /script/info/hap-$HAPP.var ] && . /script/info/hap-$HAPP.var
  [ "$HAPP_HTTP" == "Y" ] && [ "$HAPP_HTTPS" == "N" ] && OPT="HTTP only"
  [ "$HAPP_HTTP" == "N" ] && [ "$HAPP_HTTPS" == "Y" ] && OPT="HTTPS only"
  [ "$HAPP_HTTP" == "Y" ] && [ "$HAPP_HTTPS" == "Y" ] && OPT="HTTP and HTTPS"
  # show connection port
  [ -n "$HAPP_PORT" ] && PORT="$HAPP_PORT" || PORT="error!"
  # include all domanis and URIs
  DOMS=$(echo $HAPP_URIS | xargs -n1)
  for DOM in $DOMS; do
    LIST+="\n  $DOM"
  done

  MSG=" Check your configuration for Application: $HAPP"
  MSG+="\n\nSecure (or not) connection type: $OPT"
  MSG+="\n\nURIs to access this application:"
  local HAPP_URI=""
  for URI in $HAPP_URIS; do
    # Lista URIs na tela
    MSG+="\n  $URI"
    # Guarda primeira como principal
    [ -z "$HAPP_URI" ] && HAPP_URI="$URI"
  done
  MSG+="\n\nAmbient variables created:"
  MSG+="\n  PORT=$HAPP_PORT"
  MSG+="\n  ROOT_URL=$HAPP_URI"
  MSG+="\n\n Is this correct?"
  if ( ! whiptail --title "NFAS - Configure an Application" --yesno "$MSG" --no-button "Back" 22 78) then
    return 1
  fi
  return 0
}

#-----------------------------------------------------------------------
# Application Configuration Menu
function ConfigAppMenu() {
  # Read read return variables from selection/creation
  . /script/info/tmp.var
  while true; do
    MENU_IT=$(whiptail --title "NFAS - Configure an Application" --cancel-button "Back"  \
        --menu "\nSelect a configuration for App: $APP_NAME" --fb 20 75 5                \
        "1" "Configure HTTP and/or HTTPS access, current is: $(GetAppSecurity $APP_NAME)"\
        "2" "Configure access URL/URIs (domains)"                         \
        "3" "Add a Public Key"                                            \
        "4" "Remove a Public Key"                                         \
        "5" "Create a GIT repository"                                     \
        3>&1 1>&2 2>&3)
    if [ $? != 0 ]; then
      CheckAppConfig $APP_NAME
      [ $? == 0 ] && return
    fi

    # Next menu or operation
    [ "$MENU_IT" == "1" ] && /script/haproxy.sh --appconn $APP_NAME
    [ "$MENU_IT" == "2" ] && /script/haproxy.sh --appuris $APP_NAME
    # These are in functions.sh
    [ "$MENU_IT" == "3" ] && AskNewKey $APP_NAME /home/$APP_NAME
    [ "$MENU_IT" == "4" ] && DeleteKeys $APP_NAME /home/$APP_NAME
    [ "$MENU_IT" == "5" ] && /script/userapp.sh --newgit $APP_NAME

  done # menu loop
}

#-----------------------------------------------------------------------
# Applications Menu loop
function AppMenu(){
  local CUR_SSL
  while true; do
    # Get global security level every time, it may change
    . /script/info/haproxy.var
    [ "$HAP_CRYPT_LEVEL" == "1" ] && CUR_SSL="MODERN"
    [ "$HAP_CRYPT_LEVEL" == "2" ] && CUR_SSL="INTERMEDIATE"
    [ "$HAP_CRYPT_LEVEL" == "3" ] && CUR_SSL="ANTIQUE"
    # Show menu
    MENU_IT=$(whiptail --title "NFAS - Manage Applications" --cancel-button "Back"     \
        --menu "\nSelect a reconfiguration command:" --fb 20 75 4    \
        "1" "Config an existing Application"                       \
        "2" "Create a NEW Application (Linux user)"                \
        "3" "List existing Applications and domains/URIs"          \
        "4" "Global Security Level for HTTP/SSL, current=$CUR_SSL" \
        3>&1 1>&2 2>&3)
    [ $? != 0 ] && return

    # Next menu or operation
    [ "$MENU_IT" == "3" ] && /script/userapp.sh --list
    [ "$MENU_IT" == "4" ] && /script/haproxy.sh --ssl

    # Create or select an Application
    if [ "$MENU_IT" == "1" ]; then
      /script/userapp.sh --chgapp      # Select Application from /home and users
      ConfigAppMenu                    # Next Menu
    fi
    if [ "$MENU_IT" == "2" ]; then
      /script/userapp.sh --newapp      # Create and configure defaults
      [ $? == 0 ] && ConfigAppMenu     # if not aborted, Next Menu
    fi
  done # menu loop
}

#-----------------------------------------------------------------------
# Main iteractive loop
# main()
while true; do
  MENU_IT=$(whiptail --title "$TITLE" --cancel-button "End"     \
      --menu "\nSelect a reconfiguration command:" --fb 20 75 5 \
      "1" "List existing Applications and domains/URIs"         \
      "2" "Manage Applications, create/config and Access"       \
      "3" "Machine config: Hostname, notificaçions, RTC..."     \
      "4" "Machine Security: SSH, root..."                      \
      "5" "Install pre-configured Programs"                     \
      3>&1 1>&2 2>&3)
  if [ $? != 0 ]; then
      echo "Menu closed."
      # Before exiting, must verify if HAproxy canfig has changed
      . /script/info/haproxy.var
      if [ "$HAP_NEW_CONF" == "Y" ]; then
        /script/haproxy.sh --reconfig
      fi
      exit 0
  fi

  # Próximo menu ou funções para cada operação
  [ "$MENU_IT" == "1" ] && /script/userapp.sh --list
  [ "$MENU_IT" == "2" ] && AppMenu
  [ "$MENU_IT" == "3" ] && echo "3: máquina"
  [ "$MENU_IT" == "4" ] && /script/ssh.sh
  [ "$MENU_IT" == "5" ] && /script/progs.sh
done #  menu loop

#-----------------------------------------------------------------------
# Loop do Menu principal interativo
function OldMenu(){
  while true; do
    MENU_IT=$(whiptail --title "NFAS - Node.js Full Application Server" \
        --cancel-button "Terminar"                                      \
        --menu "Selecione um comando de reconfiguração:" --fb 20 70 9   \
        "1" "Testar Email de notificação"  \
        "2" "Alterar Email de notificação" \
        "3" "Alterar Hostname"             \
        "4" "Alterar Time Zone do sistema (localtime)" \
        "5" "Instalar programas pré-configurados"      \
        "6" "Configuração de SSH e acesso de ROOT"     \
        "7" "Nível global de Segurança HTTPS/SSL"      \
        "8" "Criar nova Aplicação (usuário Linux)"     \
        "9" "Configurar acesso WEB a uma Aplicação"    \
        3>&1 1>&2 2>&3)
    status=$?
    if [ $status != 0 ]; then
        echo "Seleção cancelada."
        # Na saída precisa verificar o HAproxy se algo mudou
        . /script/info/haproxy.var
        if [ "$HAP_NEW_CONF" == "Y" ]; then
          /script/haproxy.sh --reconfig
        fi
        exit 0
    fi

    # Comando local: enviar Email de teste
    if [ "$MENU_IT" == "1" ];then
      /script/email.sh --test
    fi
    # Comando local: Altera dados do Email de notifucação
    if [ "$MENU_IT" == "2" ]; then
      /script/email.sh
    fi
    # Comando local: alterar hostname
    if [ "$MENU_IT" == "3" ]; then
      /script/hostname.sh
    fi
    # Comando local: alterar Time Zone
    if [ "$MENU_IT" == "4" ]; then
      /script/clock.sh --localtime
    fi
    # Comando local: instalar programas
    if [ "$MENU_IT" == "5" ]; then
      /script/progs.sh
    fi
    # Comando local: alterar SSH e acesso de root
    if [ "$MENU_IT" == "6" ]; then
      /script/ssh.sh
    fi
    # Comando local: alterar SSH e acesso de root
    if [ "$MENU_IT" == "7" ]; then
      /script/haproxy.sh --ssl
    fi
    # Comando local: criar nova Aplicação
    if [ "$MENU_IT" == "8" ]; then
      /script/userapp.sh --newapp
    fi
    # Comando local: Configurar acesso a uma Aplicação
    if [ "$MENU_IT" == "9" ]; then
      /script/userapp.sh --chgapp
    fi
  done # loop menu principal
  return
}

#-----------------------------------------------------------------------

