#!/bin/bash
# set -x

# Script to create a new Application (Linux user)
# Uso: /script/userapp.sh
# <cmd>: --root-pwd    Check and asks root password if none exists
#        --first       First install
#        --newapp      Create a new application
#        --chgapp      Change Config of an existing application
#        <nothing>     not used

#=======================================================================
# Process command line
CMD=$1
# Auxiliary Functions
. /script/functions.sh
# Read previous configurations if they exist
. /script/info/distro.var
# Global variables (to this script)
APP_NAME=""
REPO_DIR=""
ROOT_PW=""
TITLE="NFAS - Application and User Configuration"
# SU command is different in each distro...
[ "$DISTRO_NAME" == "CentOS" ] && SU_C="--session-command" || SU_C="-c"

#-----------------------------------------------------------------------
# Function for asking and check the name of an Application
# usage: AskName <VAR> "Name type"
# VAR is a variable that will recieve the answer
# "Name type" is the type of name, this will be shown on screen
# Retorns: 0=ok, 1=Aborta se <Cancelar>
function AskName(){
  local VAR=$1
  local SHOW=$2
  local TMP=""
  local ERR_ST=""
  local NAME_TMP
  # Get previous value of Name
  eval TMP=\$$VAR
  # Endless loop, exits through menu
  while true; do
    MSG="\n\nWhat is $SHOW (must be a valid Linux user name)?\n"
    # Add error message from previous loop
    MSG+="\n\n$ERR_ST\n"
    # whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
    TMP=$(whiptail --title "$TITLE" --inputbox "$MSG" 14 74 $TMP 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ ${#TMP} -eq 0 ]; then
      echo "Operation aborted!"
      return 1
    fi
    # Test if there are only valid characters
    # http://serverfault.com/questions/73084/what-characters-should-i-use-or-not-use-in-usernames-on-linux
    NAME_TMP=$(echo $TMP | grep -E '^[a-zA-Z0-9_][a-zA-Z0-9_-.]*[a-zA-Z0-9_]$')
    # Check invalid combinations
    if [ "$NAME_TMP" != "" ] &&        # Check if empty, could have been refused by ER
       [ "$NAME_TMP" == "$TMP" ]; then # Was not changed by the ER
      # Valid name, check if there is already a user by that name
      id $NAME_TMP
      if [ $? -eq 0 ]; then
        ERR_ST="There already exists a Linux user with that name, please try again"
      else
        # Check if there is a group with that name
        egrep -i "^$NAME_TMP" /etc/group
        if [ $? -eq 0 ]; then
          ERR_ST="There already exists a Linux group with that name, please try again"
        else
          eval "$VAR=$TMP"
          return 0
        fi
      fi
    else
      ERR_ST="Invalid name, please try again"
    fi
  done

}

#-----------------------------------------------------------------------
# Function for asking and verifying a Password
# usage: AskPasswd <VAR> "Passwd type" <opt>
# VAR is a variable that will recieve the answer
# "Passwd type" is the type of password, this will be shown on screen
# Retorns: 0=ok, 1=Abort if <Cancel>
function AskPasswd(){
  local VAR=$1
  local SHOW=$2
  local OPT="$3"
  local MSG
  local TMP=""
  local ERR_ST=""
  local PWD_TMP PWD1 PWD2 PWD3
  # Get previous value of Password
  eval TMP=\$$VAR
  # Endless loop, exits through menu
  while true; do
    MSG="\nWhat is $SHOW"
    MSG+="\n\nValid characters: a-zA-Z0-9!@#$%^&*()_-+={};:,./?"
    MSG+="\n  (use a secure password...)"
    # Add error message from previous loop
    MSG+="\n\n$ERR_ST"
    # whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
    PWD1=$(whiptail --passwordbox $OPT --title "$TITLE"  "$MSG" 14 74 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operation aborted!"
      return 1
    fi
    MSG="\n\n Type the Password again for verification\n\n\n\n"
    PWD2=$(whiptail --passwordbox $OPT --title "$TITLE"  "$MSG" 14 74 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operation aborted!"
      return 1
    fi
    if [ "$PWD1" != "$PWD2" ]; then
      ERR_ST="Both Passwords do no match, please try again"
    else
      # Check if there are only valid caracteres
      # Remove double quotes: A='ab"12"3'; echo "${A//'"'}"
      # Remove single quotes: A="ab'12'3"; echo "${A//"'"}"
      PWD2="${PWD1//'"'}"
      PWD3="${PWD2//"'"}"
      echo $PWD3 | grep -q -E '^[a-zA-Z0-9!@#$%^&*()_-+=\{\};:,./?]+$'
      if [ $? -eq 0 ] && [ ${#PWD3} -ne 0 ] && [ "$PWD1" == "$PWD3" ]; then
        # Name accepted, Continue
        eval "$VAR=$PWD1"
        return 0
      else
        ERR_ST="Passwors is invalid, please try again"
      fi
    fi
  done
}

#-----------------------------------------------------------------------
# Procedure to create a NEW Application (Linux user)
function NewApp(){
  local NEW_PWD
  # APP_NAME is global
  AskName APP_NAME "Application name"
  [ $? != 0 ] && return 1
  AskPasswd NEW_PWD "user Password \"$APP_NAME\""
  [ $? != 0 ] && return 1
  # echo "New Aplication: $APP_NAME, passwd: $NEW_PWD"
  # Criating user
  # NOTE: useradd doesn't create user's home directory on Ubuntu 14.04, only with "-m"
  useradd -m $APP_NAME
  if [ "$DISTRO_NAME" == "CentOS" ]; then
    echo "$NEW_PWD" | passwd --stdin $APP_NAME > /dev/null
  else
    # NOTE: --stdin only works on CentOS (not on Ubuntu 14.04)
    # http://ccm.net/faq/790-changing-password-via-a-script
    # echo "$NEW_PWD" | passwd --stdin $APP_NAME
    echo "Ubuntu..."
  fi
  # Other scripts that need to reconfigure
  /script/console.sh --newuser $APP_NAME
  /script/postfix.sh --newuser $APP_NAME
  # Initialization script
  mkdir /home/$APP_NAME/app
  cp -a /script/auto.sh /home/$APP_NAME
  cp -a /script/server.js /home/$APP_NAME/app
  chown -R $APP_NAME:$APP_NAME /home/$APP_NAME
  # Create default HAproxy configuration
  /script/haproxy.sh --newapp $APP_NAME
  # Returns the Application name to the caller
  echo "APP_NAME=$APP_NAME" >/script/info/tmp.var
  return 0
}

#-----------------------------------------------------------------------
# Application select screen
# Uses as reference directories in /home
function SelectApp(){
  local I AUSR USR NUSR KEYS
set -x
  APP_NAME="" # Clear output variable
  # create Array of existing users
  NUSR=0
  for USR in $(ls /home) ; do
    id $USR
    if [ $? -eq 0 ]; then
      echo "User found: $USR"
      AUSR[$NUSR]=$USR
      let NUSR=NUSR+1 # Number of lines
    fi
  done
  if [ "$NUSR" == "0" ]; then
    whiptail --title "$TITLE" --msgbox "No Application/User was found." 8 50
    return 1
  fi
  # whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
  EXE="whiptail --title \"$TITLE\""
  EXE+=" --menu \"\nSelecect the Aplication/User to configure\" 20 60 $NUSR"
  for ((I=0; I<NUSR; I++)); do
    # Create the messages for application selection
    EXE+=" \"${AUSR[$I]}\" \"\""
  done
  KEYS=$(eval "$EXE 3>&1 1>&2 2>&3")
  [ $? != 0 ] && return 2 # Aborted
  APP_NAME=$KEYS
  # Returns the Application name to the caller
  echo "APP_NAME=$APP_NAME" >/script/info/tmp.var
set +x
}

#-----------------------------------------------------------------------
# Ask name of Git repository
# usage: AskRepoName <VAR> Aplication
# VAR is a variable that will recieve the answer
function AskRepoName(){
  local VAR=$1
  local USR=$2
  local TMP
  local DIR_TMP
  while true; do
     MSG="\nWhat is the diretory for the repository to be created?"
    MSG+="\n  (will be created inside /home/$USR)\n"
    MSG+="\n\n$ERR_ST\n"
    # whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
    TMP=$(whiptail --title "$TITLE" --inputbox "$MSG" 14 74 $TMP 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operation aborted!"
      return 1
    fi
    # Test if there are only valid characters
    # http://serverfault.com/questions/73084/what-characters-should-i-use-or-not-use-in-usernames-on-linux
    REPO_TMP=$(echo $TMP | grep -E '^[a-zA-Z0-9_][a-zA-Z0-9_-.]*[a-zA-Z0-9_]$')
    # Check invalid combinations
    if [ "$REPO_TMP" != "" ] &&        # Check if empty, could have been refused by ER
       [ "$REPO_TMP" == "$TMP" ]; then # Was not changed by the ER
      # Valid name, check if there is already a directory by that name
      ls /home/$USR/$REPO_TMP  &> /dev/null
      if [ $? -eq 0 ]; then
        # Diretory name is in use
        ERR_ST="Este nome já está em uso, por favor tente novamente"
      else
        eval "$VAR=/home/$USR/$REPO_TMP"
        return 0
      fi
    else
      ERR_ST="Invalid name, please try again"
    fi
  done
}

#-----------------------------------------------------------------------
# Create a GIT repository
# usage: CreateRepo <user>
function CreateRepo(){
  local USR=$1
  # Read directory name and check if it exists
  AskRepoName REPO_DIR $USR
  # Create directory for the repository, has to be created as user
  su $USR -l -c "mkdir -p $REPO_DIR"
}

#-----------------------------------------------------------------------
# Submenu to configue Application access
# Input global variable: APP_NAME
function ConfigApp(){
  local MENU_IT
  local MSG9
  while true; do
    # On first run, uses the option "continue" for easier understanding
    if [ "$CMD" == "--first" ]; then
      MENU_IT=$(whiptail --title "$TITLE" \
        --menu "\nReconfiguration command, aplication: \"$APP_NAME\"" --fb 18 70 5   \
        "1" "Configure HTTP(S) and access URL/URI" \
        "2" "Add Public Key"                       \
        "3" "Remove Public Key"                    \
        "4" "Create GIT Repository"                \
        "9" "Continue..."                          \
        3>&1 1>&2 2>&3)
    else
      MENU_IT=$(whiptail --title "$TITLE" --cancel-button "Return" \
        --menu "\nReconfiguration command, aplication: \"$APP_NAME\"" --fb 18 70 4   \
        "1" "Configure HTTP(S) and access URL/URI" \
        "2" "Add Public Key"                       \
        "3" "Remove Public Key"                    \
        "4" "reate GIT Repository"                 \
        3>&1 1>&2 2>&3)
    fi
    [ $? != 0 ] && return 0 # Aborted
    [ "$MENU_IT" == "9" ] && return 0 # End
    #  Configure URIs
    [ "$MENU_IT" == "1" ] && /script/haproxy.sh --app $APP_NAME
    # New PublicKey
    [ "$MENU_IT" == "2" ] && AskNewKey $APP_NAME /home/$APP_NAME
    # Remove root PublicKey
    [ "$MENU_IT" == "3" ] && DeleteKeys $APP_NAME /home/$APP_NAME
    # Create GIT Repository
    [ "$MENU_IT" == "4" ] && CreateRepo $APP_NAME
  done
}

#-----------------------------------------------------------------------
# main()

if [ "$CMD" == "--first" ]; then
  NewApp
  if [ $? == 0 ]; then
    AskNewKey $APP_NAME /home/$APP_NAME
    /script/haproxy.sh --app $APP_NAME
    # Start with a default example App, this helps tests
    su - $APP_NAME $SU_C "nohup /home/$APP_NAME/auto.sh </dev/null 2>&1 >/dev/null &"
  fi

#-----------------------------------------------------------------------
elif [ "$CMD" == "--root-pwd" ]; then
  # Called from first.sh, check if root has a password
  # http://www.tldp.org/LDP/lame/LAME/linux-admin-made-easy/shadow-file-formats.html
  if [ "$(cat /etc/shadow | grep -E "^root" | cut -d: -f2)" == "*" ]; then
    AskPasswd ROOT_PW "root passord (it has none)" --nocancel
    if [ "$DISTRO_NAME" == "CentOS" ]; then
      echo "$ROOT_PW" | passwd --stdin root
    else
      # NOTE: See in function NewApp
      echo "Ubuntu..."
    fi
  fi

#-----------------------------------------------------------------------
elif [ "$CMD" == "--newapp" ]; then
  # Called by menu nfas.sh
  NewApp
  # if [ $? == 0 ]; then
  #   /script/haproxy.sh --app $APP_NAME
  #   # Start with a default example App
  #   su - $APP_NAME $SU_C "nohup /home/$APP_NAME/auto.sh </dev/null 2>&1 >/dev/null &"
  #   # .bashrc is configured by haproxy.sh --app, so the connection test must come last
  #   AskNewKey $APP_NAME /home/$APP_NAME
  # fi

#-----------------------------------------------------------------------
elif [ "$CMD" == "--chgapp" ]; then
  # Called by menu nfas.sh
  SelectApp
  # if [ $? == 0 ]; then
  #   ConfigApp $APP_NAME
  # fi

#-----------------------------------------------------------------------
fi
