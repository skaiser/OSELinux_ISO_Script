#!/bin/bash
###########################################################################
# Script to buidl the ISO image for OSE Linux
# Copyright 2017 Stephen Kaiser
#
# MIT LICENSE
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files 
# (the "Software"), to deal in the Software without restriction, 
# including without limitation the rights to use, copy, modify, merge, 
# publish, distribute, sublicense, and/or sell copies of the Software, 
# and to permit persons to whom the Software is furnished to do so, 
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT
# OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR 
# THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
###########################################################################
#
# Notes:
# The steps to unpack and repackage the iso were taken and tested from the following guides,
# lots of tools and guides on internet seemed to not work, including the ubuntu official guide:
#
# https://nathanpfry.com/how-to-customize-an-ubuntu-installation-disc/
# https://www.codinglogs.com/build-your-own-linux-live-distribution-based-on-ubuntu/
###########################################################################

# Install the prerequisite software, which allows you to unpack and 
# repackage the iso with the following commasend(enter your root password 
# upon prompt):

sudo apt-get install squashfs-tools genisoimage


# Create a new folder for your working directory - you will require 
# approximately 10 gigabytes of free hard drive space for decompressing and
# repackaging it, use the following command to create new directory:

mkdir oseimage


# Copy the downloaded base image into the new directory using the following 
# commands, replacing the old path, new path, and name of your ubuntu iso: 

cp /path/to/saved/ubuntu.iso ~/where/to/save/custom-img
cd ~/custom-img 


# Now extract the contents of the image 

mkdir mnt 
sudo mount -o loop ubuntu.iso mnt


# Here you will get a mount protected read-only warning, don’t worry, ISO's 
# only do mount read-only, that is why we will extract its fs to customize 
# in the upcoming steps.

mkdir extract
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract


# Now extract the file system using following commands:

sudo unsquashfs mnt/casper/filesystem.squashfs
sudo mv squashfs-root edit


# We need access to internet in the chroot environment of the ubuntu installation
# to be able to add/update the ubuntu installation and its packages, we can do so
# by copying the resolv.conf from our system to the installation file system:

sudo cp /etc/resolv.conf edit/etc/


# We now need to mount important directories before we can start editing the ubuntu
# installation 

sudo mount --bind /dev/ edit/dev
sudo chroot edit


# This puts us inside the chroot environment of the ubuntu installation

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts


# Following commands are need to make everything run smoothly.

export HOME=/root
export LC_ALL=C
# Note: LC_ALL is the environment variable that overrides all the other localisation
# settings. The C locale is a special locale that is meant to be the simplest locale.
# You could also say that while the other locales are for humans, the C locale is for
# computers. In the C locale, characters are single bytes, the charset is ASCII (well,
# is not required to, but in practice will be in the systems most of us will ever get
# to use), the sorting order is based on the byte values, the language is usually US
# English (though for application messages (as opposed to things like month or day 
# names or messages by system libraries), it's at the discretion of the application 
# author) and things like currency symbols are not defined.


# The dbus-uuidgen command generates or reads a universally unique ID.

dbus-uuidgen > /var/lib/dbus/machine-id


# dpkg-divert is the utility used to set up and update the list of diversions. File 
# diversions are a way of forcing dpkg(1) not to install a file into its location, 
# but to adiverted location.

dpkg-divert --local --rename --add /sbin/initctl


# Use to create a symbolic link

ln -s /bin/true /sbin/initctl


#####################################################################################
# Now we can start customizing our ubuntu installation. I will only cover adding and 
# removing software in this guide, even though just about anything can be customized 
# using the command line. You can remove a package by the following command:
# apt-get purge package1 paackage2
# We are using purge command to remove data + config files of the package, optimizing 
# the space required for the ISO.
# You can remove games, scanning utilities, and other unncessary packages, but stay 
# away from core components unless you know what you are doing.
#####################################################################################

# Since we are customizing a 64-bit Ubuntu image, we need multiarch (i386) support for 
# some of the programming libraries. The following command is not necessary for 
# everyone, but I recommend it anyway:

dpkg --add-architecture i386


# Update the software repositories and packages before we proceed with the following:

apt-get update
apt-get upgrade


# Now we are going to add the necessary packages into our ubuntu installation. We are 
# adding FreeCAD, kdenlive, Vokoscreen, and Chromium Browser

# FreeCAD and FreeCAD-doc
sudo add-apt-repository ppa:freecad-maintainers/freecad-stable
# Press ‘Enter’ when promoted
echo 'deb http://cz.archive.ubuntu.com/ubuntu xenial main universe' >> /etc/apt/sources.list
apt-get update
apt-get install freecad freecad-doc

# Install assembly and fasteners workbench by first adding the freecad-community repository and then installing them 
sudo add-apt-repository ppa:freecad-community/ppa
# Press ‘Enter’ when promoted
sudo apt-get update
apt-get install  freecad-extras-assembly2 
apt-get install  freecad-extras-fasteners

# Kdenlive
apt-get install kdenlive

# Vokoscreen 
apt-get install vokoscreen

# Chromium Browser 
apt-get instal chromium-browser 

# Finally update and upgrade all packages
apt-get update
apt-get upgrade

#####################################################################################
# Now it is time to clean up and repackage the iso
#####################################################################################
apt-get autoremove && apt-get autoclean
rm -rf /tmp/* ~/.bash_history
rm /etc/resolv.conf
rm /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initct

# Unmount all the directories
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts
exit
sudo umount edit/dev

#####################################################################################
# PRODUCE THE ISO
# You have now “logged out” of the installation environment and are “back” on the host 
# system. These final steps will actually produce the ISO.
#####################################################################################
# Generate a new manifest
sudo chmod +w extract/casper/filesystem.manifest
sudo chroot edit dpkg-query -W --showformat='${Package} ${Version}n' | sudo tee extract/casper/filesystem.manifest
sudo cp extract/casper/filesystem.manifest extract/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' extract/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' extract/casper/filesystem.manifest-desktop

# Compressing the filesystem
sudo mksquashfs edit extract/casper/filesystem.squashfs -b 1048576

# Update filesystem size (needed by the installer):
printf $(sudo du -sx --block-size=1 edit | cut -f1) | sudo tee extract/casper/filesystem.size

# Delete the old md5sum:
cd extract
sudo rm md5sum.txt

# Now generate a fresh one: (single command, copy and paste in one piece)
find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt

# And finally, create the ISO. This is a single long command, be sure to copy and paste 
# it in one piece and don’t forget the period at the end, it’s important:
sudo genisoimage -D -r -V "$OSE" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../ose0.4.iso .

# Test the ISO using the following guide on VirtualBox - no USB creation required 
# https://help.ubuntu.com/community/VirtualBox
