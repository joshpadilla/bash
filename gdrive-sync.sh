#!/bin/bash
# Google Drive Sync
#
# Author: Josh Padilla <joshpadilla@gmail.com>
#
# Config BEGIN
# =====================================================================

# Directory to backup
BACKUPDIR=/var/backups

# Google Drive directory
GDRIVEDIR=/mnt/GoogleDrive

# Directory target in remote
TARGETDIR=/backups

# =====================================================================
# Config END

# Create backup dir if not exists
echo Creating ${GDRIVEDIR}/${TARGETDIR} if needed
if [ ! -d "${GDRIVEDIR}/${TARGETDIR}" ]; then mkdir ${GDRIVEDIR}/${TARGETDIR}; fi

# Moving to Gdrive Dir
echo Entering ${GDRIVEDIR}
cd ${GDRIVEDIR}

# Initial sync
echo Initial Google Drive Sync
grive

# Coping new content
echo Copying from ${BACKUPDIR}/* to ${GDRIVEDIR}/${TARGETDIR}/
cp -R ${BACKUPDIR}/* ${GDRIVEDIR}/${TARGETDIR}/

# Showing files copied
echo Files to sync
find ${GDRIVEDIR}/${TARGETDIR}/

# Final sync
echo Final Google Drive Sync
grive







































