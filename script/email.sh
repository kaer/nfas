#!/bin/bash
# set -x

# Script para perguntar email do administrador e servidor smtp
# As perguntas são interativas através de TUI
# No final chama os scrips que necessitam de atualização

#-----------------------------------------------------------------------
# Função para perguntar e verificar um Email
# uso: AskEmail <VAR> "Nome do email"
# VAR é a variável que vai receber o Email
# NOME é para mostrar na tela
# Retorna: 0=ok, 1=Aborta se <Cancelar>
function AskEmail(){
  local VAR=$1
  local NOME=$2
  local TMP=""
  local ERR_ST=""
  # Prepara valor inicial
  if [ "$FIRST" == "Y" ]; then
    TMP=""
  else
    # pega valor enterior do Email
    eval TMP=\$$VAR
  fi
  # loop só sai com return
  while true; do
    MSG="\nQual o $NOME (para envio de notificações)?\n"
    if [ -n "$TMP" ]; then
      MSG+="\n<Enter> para manter o anterior sendo mostrado\n"
    fi
    # Acrescenta mensagem de erro
    MSG+="\n$ERR_ST"
    # uso do whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
    TMP=$(whiptail --title "Configuração NFAS" --inputbox "$MSG" 13 74 $TMP 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operação cancelada!"
      ABORT="Y"
      return 1
    fi
    # Validação do nome
    # Site ajudou: http://www.regular-expressions.info/email.html
    LC_CTYPE="C"
    # Testa se só tem caracteres válidos
    EMAIL_TMP=$(echo $TMP | grep -E '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$')
    # Testa combinações inválidas
    if [ "$EMAIL_TMP" != "" ] &&                # testa se vazio, pode ter sido recusado pela ER...
       [ "$EMAIL_TMP" == "$TMP" ]; then # Não foi alterado pela ER
      # Email aceito, Continua
      eval $VAR="$TMP"
      echo "$NOME ok: \$$VAR"
      return 0
    else
      ERR_ST="Email inválido, por favor tente novamente"
    fi
  done
}

#-----------------------------------------------------------------------
# Função para perguntar URL do Servidor de SMTP
# uso: AskEmailSmtp
# Retorna: 0=ok, 1=Aborta se <Cancelar>
function AskEmailSmtp(){
  local ERR_ST=""
  if [ "$FIRST" == "Y" ]; then
    EMAIL_SMTP_URL=""
  fi
  # loop só sai com return
  while true; do
    MSG="\nQual o servidor de SMTP (para envio de notificações)?\n"
    if [ -n "$EMAIL_SMTP_URL" ]; then
      MSG+="\n<Enter> para manter o anterior sendo mostrado\n"
    fi
    # Acrescenta mensagem de erro
    MSG+="\n$ERR_ST"
    # uso do whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
    EMAIL_SMTP_URL=$(whiptail --title "Configuração NFAS" --inputbox "$MSG" 13 74 $EMAIL_SMTP_URL 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operação cancelada!"
      ABORT="Y"
      return 1
    fi
    # Validação do nome
    # Site ajudou: http://stackoverflow.com/questions/15268987/bash-based-regex-domain-name-validation
    LC_CTYPE="C"
    # Testa se só tem caracteres válidos
    SMTP_TMP=$(echo $EMAIL_SMTP_URL | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+\.(?:[a-zA-Z]{2,})$)')
    # Testa combinações inválidas
    if [ "$SMTP_TMP" != "" ] &&                   # testa se vazio, pode ter sido recusado pela ER...
       [ "$SMTP_TMP" == "$EMAIL_SMTP_URL" ]; then # Não foi alterado pela ER
      # Email do Admin aceito, Continua
      echo "Servidor de SMTP ok: $EMAIL_SMTP_URL"
      return 0
    else
      ERR_ST="URL inválido, por favor tente novamente"
    fi
  done
}

#-----------------------------------------------------------------------
# Função para perguntar Porta do Servidor de SMTP
# uso: AskEmailSmtpPort
# Retorna: 0=ok, 1=Aborta se <Cancelar>
function AskEmailSmtpPort(){
  local ERR_ST=""
  # loop só sai com return
  while true; do
    MSG="\nQual a PORTA a ser usada do servidor de SMTP?\n"
    # http://pt.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol
    MSG+="(Default geralmente é 465)"
    if [ "$FIRST" == "Y" ]; then
      EMAIL_SMTP_PORT=465
    fi
    MSG+="\n<Enter> para manter o anterior sendo mostrado\n"
    # Acrescenta mensagem de erro
    MSG+="\n$ERR_ST"
    # uso do whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail
    EMAIL_SMTP_PORT=$(whiptail --title "Configuração NFAS" --inputbox "$MSG" 13 74 $EMAIL_SMTP_PORT 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operação cancelada!"
      ABORT="Y"
      return 1
    fi
    # Validação do nome, Testa se só tem dígitos
    SMTP_TMP=$(echo $EMAIL_SMTP_PORT | grep -E '^[0-9]{1,6}$')
    # Testa combinações inválidas
    if [ "$SMTP_TMP" != "" ] &&                    # testa se vazio, pode ter sido recusado pela ER...
       [ $SMTP_TMP -lt 65536 ] &&                  # Portas até 65535
       [ "$SMTP_TMP" == "$EMAIL_SMTP_PORT" ]; then # Não foi alterado pela ER
      # Email do Admin aceito, Continua
      echo "Porta do servidor de SMTP ok: $EMAIL_SMTP_PORT"
      return 0
    else
      ERR_ST="Porta inválida, por favor tente novamente"
    fi
  done
}

#-----------------------------------------------------------------------
# Função para perguntar se usa StartTLS
# uso: AskEmailSmtpStartTls
# Retorna: 0=ok, 1=Aborta se <Cancelar>
function AskEmailSmtpStartTls(){
  MSG="\nPrecisa usar o comando StartTLS?\n"
  MSG+="(é necessário para o Gmail...)\n"
  # uso do whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail#Yes.2Fno_box
  whiptail --title "Configuração NFAS" --yesno --defaultno "$MSG" 10 78
  if [ $? -eq 0 ]; then
    EMAIL_SMTP_STARTTLS="Y"
  else
    EMAIL_SMTP_STARTTLS="N"
  fi
}

#-----------------------------------------------------------------------
# Função para perguntar a Senha
# uso: AskEmailPasswd
# Retorna: 0=ok, 1=Aborta se <Cancelar>
function AskEmailSmtpPasswd(){
  local ERR_ST=""
  local PW1=""
  local PW2=""
  local TMP=""
  if [ "$FIRST" != "Y" ]; then
    PW1="$EMAIL_USER_PASSWD"
  fi
  # loop só sai com return
  while true; do
    MSG="\nQual a Senha do usuário para LOGIN?\n"
    # Acrescenta mensagem de erro
    MSG+="\n$ERR_ST"
    # uso do whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail#Password_box
    PW1=$(whiptail --title "Configuração NFAS" --passwordbox "$MSG" 10 78 $PW1 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operação cancelada!"
      ABORT="Y"
      return 1
    fi
    MSG="\nQual a Senha do usuário para LOGIN?\n"
    MSG+="\n Por favor repita a senha para conferência"
    if [ "$FIRST" != "Y" ] && [ "$PW1" == "$EMAIL_USER_PASSWD" ]; then
      PW2="$EMAIL_USER_PASSWD"
    fi
    PW2=$(whiptail --title "Configuração NFAS" --passwordbox "$MSG" 10 78 $PW2 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      echo "Operação cancelada!"
      ABORT="Y"
      return 1
    fi
    # Validação do nome, expressão corta no primeiro " "
    TMP=$(echo $PW1 | sed 's/^\(.*\)[ ].*$/\1/')
    # Testa combinações inválidas
    if [ "$PW1" != "" ] &&            # testa se vazio
       [ "$PW1" == "$PW2" ] &&        # têm que ser iguais
       [ "$TMP" == "$PW1" ]; then     # Não foi alterado pela ER
      # Senha aceita, Continua
      EMAIL_USER_PASSWD="$PW1"
      echo "Senha ok: $EMAIL_USER_PASSWD"
      return 0
    else
      PW1=""
      PW2=""
      ERR_ST="Senha inválida, por favor tente novamente"
    fi
  done
}

#==========================================================================
# Começo
#==========================================================================

# Arquivo de Informação gerado
INFO_FILE=/script/info/email.var

# Processa a linha de comando
if [ "$1" == "--first" ]; then
  # Chamado pelo Script de instalação inicial
  FIRST="Y"
else
  FIRST="N"
fi
# Lê dados anteriores
. $INFO_FILE

#-----------------------------------------------------------------------
# Loop de perguntas
#-----------------------------------------------------------------------
FIM="N"; ABORT="N"
# Loop para começar tudo de novo
while [ $FIM != "Y" ]; do
  # ----- Pergunta o Email do Admin na tela
  AskEmail "EMAIL_ADMIN" "Email do Admin"
  # ----- Pergunta o Servidor de SMTP na tela
  [ "$ABORT" != "Y" ] && AskEmailSmtp
  # ----- Pergunta a Porta do Servidor
  [ "$ABORT" != "Y" ] && AskEmailSmtpPort
  # ----- Pergunta sobre o StartTLS
  [ "$ABORT" != "Y" ] && AskEmailSmtpStartTls
  # ----- Pergunta o Email do Admin na tela
  [ "$ABORT" != "Y" ] && AskEmail "EMAIL_USER_ID" "Email do usuário para LOGIN"
  # ----- Pergunta a Senha
  [ "$ABORT" != "Y" ] && AskEmailSmtpPasswd

  # ----- Confirma Abortar
  if [ $ABORT == "Y" ]; then
    # uso do whiptail: http://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail#Yes.2Fno_box
    MSG="Deseja MESMO cancelar cadastramente de Email?\n"
    if [ "$FIRST" == "Y" ]; then
      MSG+="\n Se cancelar, não haverá envio de notificações do Sistema"
    fi
    MSG+="\n Esta operação pode ser refeita posteriormente!"
    whiptail --title "Configuração NFAS" --yesno --defaultno "$MSG" 10 78
    if [ $? -eq 0 ]; then
      echo "Cadastramento de Email cancelado. Por favor configure os Email mais tarde!"
      exit 1
    fi
  else
    # Terminou sem erros
    FIM="Y"
  fi
done # loop principal

#-----------------------------------------------------------------------
# Escreve valores obtidos
#-----------------------------------------------------------------------

echo "EMAIL_ADMIN=\"$EMAIL_ADMIN\""                        2>/dev/null >  $INFO_FILE
echo "EMAIL_SMTP_URL=\"$EMAIL_SMTP_URL\""                  2>/dev/null >> $INFO_FILE
echo "EMAIL_SMTP_PORT=\"$EMAIL_SMTP_PORT\""                2>/dev/null >> $INFO_FILE
echo "EMAIL_SMTP_STARTTLS=\"$EMAIL_SMTP_STARTTLS\""        2>/dev/null >> $INFO_FILE
echo "EMAIL_USER_ID=\"$EMAIL_USER_ID\""                    2>/dev/null >> $INFO_FILE
echo "EMAIL_USER_PASSWD=\"$EMAIL_USER_PASSWD\""            2>/dev/null >> $INFO_FILE
cat $INFO_FILE


#-----------------------------------------------------------------------
# Chama scripts que dependem do Email
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
