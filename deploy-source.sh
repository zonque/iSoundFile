#!/bin/sh

cd ..
rm -fr /tmp/iSoundFile
cp -R iSoundFile /tmp
cd /tmp/iSoundFile
find . -name .svn -print0 | xargs -0 rm -fr
find . -name \*~.nib -print0 | xargs -0 rm -fr
xcodebuild clean
rm -fr build
cd ..
tar -f iSoundFile.tar.gz -czv iSoundFile/


