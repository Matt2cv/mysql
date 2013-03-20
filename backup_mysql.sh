#!/bin/sh
# #################################### 
# Backup mysql base par base
# 1 fichier par base stocke sur disque pour envoyer sur un NAS via rsync
# 1 rapport HTML est genere permettant une visu sur forme de flux RSS
# ####################################
# Matthias (matthias@i-maj.org)
# ####################################

## Chargement de l'env.
. /root/.profile

## Variables

MYS_USER=""  	# User mysql pour le backup
MYS_PWD=""		# Mot de passe du user mysql

REP_BCK="" 						           # Repertoire pour stocker les backup sur disque
RETENTION=3						           # Periode de retention en nb de jour
EXCLUDE="information_schema"     # Database a exclure

DIST_SRV=""          			# IP du NAS
DIST_REP=""   					# point de montage NFS
export HOST=`hostname`			# Recuperation du nom d'host

DD=`date +%d/%m/%Y`
SUBJECT="[$HOST] Backup Mysql"
MAIL="matthias@i-maj.org"

REP_RAPPORT=""											# Repertoire du rapport
DATE_REPORT=`date +'%Y%m%d%H%M%S'`						# Date du rapport
RAPPORT="$REP_RAPPORT/$DATE_REPORT.backup_mysql.html"	# Nom du rapport

## Construction de la liste des bases
ListBDD=`mysql --skip-column-names -ubackup_base -p$SAUVE <<EOF
show databases;
EOF`

echo "&lt;b&gt;Start @ `date -R -u`&lt;/b&gt;&lt;br /&gt;" > $RAPPORT
echo "-----------------------------&lt;br /&gt;" >> $RAPPORT

## Backup des bases
for base in $ListBDD
do

if [ "$base" != "$EXCLUDE" ]
then

  date_bck=`date +%Y%m%d%H%M`
  file_bck="$REP_BCK/$base.$date_bck.sql"
  mysqldump -u$MYS_USER -p$MYS_PWD $base > $file_bck
  VERIF_DUMP=`echo $?`
  gzip $file_bck
  VERIF_ZIP=`echo $?`

  if [ $VERIF_DUMP -eq 0 ] && [ $VERIF_ZIP -eq 0 ]
  then

         ListFILE=`ls -lt $REP_BCK/*$base* | awk '{print $9}'`
         countFile=1
         for file in $ListFILE
         do
           if [ $countFile -gt $RETENTION ]
           then
             rm $file
           fi
           countFile=`expr $countFile + 1`
         done

         echo "&lt;font color=&quot;green&quot;&gt;&lt;b&gt;[OK]&lt;/b&gt;&lt;/font&gt; Backup $base&lt;br /&gt;" >> $RAPPORT

  else
     echo "&lt;font color=&quot;red&quot;&gt;&lt;b&gt;[KO]&lt;/b&gt;&lt;/font&gt; Backup $base&lt;br /&gt;" >> $RAPPORT
  fi

fi

done

## Transfert des backup
echo "&lt;br /&gt;" >> $RAPPORT
if [ `nmap -sP $DIST_SRV | grep "Host seems down" | wc -l` -eq 1 ]
then
   echo "&lt;font color=&quot;red&quot;&gt;&lt;b&gt;Transfert [KO] : serveur DOWN&lt;/b&gt;&lt;/font&gt;" >> $RAPPORT
else
   rsync -av --delete $REP_BCK/* $DIST_REP > /dev/null
   VERIF_TRF=`echo $?`
   if [ $VERIF_TRF -eq 0 ]
   then
      echo "&lt;font color=&quot;green&quot;&gt;&lt;b&gt;Transfert [OK]&lt;/b&gt;&lt;/font&gt;" >> $RAPPORT
      find $REP_BCK -type f -a -mtime +$RETENTION -exec rm {} \;
   else
      echo "&lt;font color=&quot;red&quot;&gt;&lt;b&gt;Transfert [KO]&lt;/b&gt;&lt;/font&gt;" >> $RAPPORT
   fi
fi

export LC_TIME=fr_FR
echo "&lt;br /&gt;---------------&lt;br /&gt;" >> $RAPPORT
echo "&lt;b&gt;Fin du rapport.&lt;/b&gt;" >> $RAPPORT

# END !
