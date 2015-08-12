#!/bin/sh
#Autor:   Eduardo Rosales
#Date:    11-nov-2014
#Version: 0.1

#======================================
#Get and set config variables
#======================================
#Constants
HELP_MESSAGE="Use -h or --help for help."
FREI0R_BUILD_DIR="build"
SOX_BUILD_DIR="build"

#Config
SCRIPT_FILE=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd -P)"
MAINTAINER="$(id -u -n)@$(hostname -f)"
#PACKAGE_CONFLICTS=""
#PACKAGE_REPLACES=""
#PACKAGE_REQUIRES="bzip2,fontconfig,libgnutls-dev,libass-dev,libbluray-dev,libcaca-dev,libfreetype6-dev,libgsm1-dev,libfaac-dev,libmp3lame-dev,libopencore-amrnb-dev,libopencore-amrwb-dev,libopenjpeg-dev,librtmp-dev,libschroedinger-dev,libspeex-dev,libtwolame-dev,libxvidcore-dev,zlib1g-dev,libsdl1.2-dev,libvdpau-dev"
#PACKAGE_PROVIDES="ffmpeg-build,ffmpeg-build-server,ffmpeg-build-play,ffmpeg-build-probe"

#Paths
#PREFIX="/usr/local"
BUILD_FOLDER="ffmpeg-build_build"
BUILD_DIR="$SCRIPT_DIR/$BUILD_FOLDER"
LIB_FOLDER="codecs"
LIB_PREFIX="$BUILD_DIR/$LIB_FOLDER"
FFMPEG_FOLDER="ffmpeg"
FFMPEG_PREFIX="$BUILD_DIR/$FFMPEG_FOLDER"
DEB_BUILD_FOLDER="package"
DEB_BUILD_DIR="$BUILD_DIR/$DEB_BUILD_FOLDER"
SOURCE_FOLDER="source-code"
SOURCE_DIR="$BUILD_DIR/$SOURCE_FOLDER"
INSTALL_DIR="opt/ffmpeg-build"

#Parameters
ACTION=""
ENABLE_SHARED="no"
ENABLE_STATIC="yes"
PACKAGE_INSTALL="yes"
BUILD_PACKAGE="yes"
HYBRID_BUILD="no"
MODE=""
SHARED_ON_OFF=""
SHARED_YES_NO=""
SHARED_ENABLED=""
SHARED_DISABLED=""
STATIC_ON_OFF=""
STATIC_YES_NO=""
STATIC_ENABLED=""
STATIC_DISABLED=""
EXISTING_SOURCE_CODE="no"
#NEW_PREFIX=""
NEW_DEB_PREFIX=""
NEW_LIB_PREFIX=""
NEW_BIN_PREFIX=""
NEW_ACTION=""
NEW_SOURCE_DIR=""
NEW_ENABLE_SHARED=""
NEW_ENABLE_STATIC=""
NEW_HYBRID_BUILD=""
NEW_PACKAGE_INSTALL=""
NEW_BUILD_PACKAGE=""
NEW_MAINTAINER=""
NEW_EXISTING_SOURCE_CODE=""

#Flags
IS_INSTALL=0
IS_REMOVE=0
IS_CLEAN=0
IS_DOWNLOAD_ONLY=0
IS_PACKAGE_INSTALL=1
IS_BUILD_PACKAGE=1
IS_SHARED=0
IS_STATIC=1
IS_HYBRID=0
SOURCE_CODE_EXISTS=0
YES_TO_ALL=0

root_when_needed() {
    if [ ! -w "$1" ]; then
        echo "sudo "
    fi
}

#Super user validation
validate_superuser() {
    #Validate that the script is executed as root
    if [ "$(id -u)" != "0" ]; then
        echo "You need superuser rights to execute this action."
        exit 1;
    fi
}

#Write access validation
validate_write_access() {
    if [ ! -w "$1" ]; then
        echo "You need write access on '$1' directory to execute this action."
        exit 1;
    fi
}

#Write access validation
validate_superuser_write_access() {
    if ! sudo test -w "$1"; then
        echo "You need write access on '$1' directory to execute this action."
        exit 1;
    fi
}

#Display a confirmation message
confirm () {
    #Call with a prompt string or use a default
    if [ $YES_TO_ALL -eq 1 ]; then
        echo "${1:-Are you sure? (y/n)} Y"
        response="Y"
    else
        read -r -p "${1:-Are you sure? (y/n)} " response
    fi
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

get_real_path() {
    AUX="$(cd "$(dirname "$0")"; pwd -P)"
    if [ $# -gt 1 ]; then
        if [ ! -d "$2" ]; then
            echo "Error: '$2' folder doesn't exists."
            exit 1
        fi
        cd "$2"
    fi
    cd "$1"
    echo "$(cd "$(dirname "$0")"; pwd -P)"
    cd $AUX
}

#Show help message
show_help() {
cat <<EOF

Description:
  This script will create ffmpeg-build package by compile ffmpeg and it's
  codecs from source code (downloaded from the projects repositories master
  branch). It can also delete the downloaded source code and generated deb
  files by using the 'clean' action.
  
  ffmpeg-build package is a FFmpeg wrapper that installs on 'opt' directory
  isolating it from system package ecosystem so there are no broken
  packages in any way.

Usage:
EOF
    echo "  ./$1 [options]"
cat <<EOF
Help:
  -h, --help               print this message

Standar Options:
  -a, --action=ACTION      specify an action execute
      install              install ffmpeg-build after the package is
                           created. FFmpeg and it's codecs are compiled
                           from source code as well as other required
                           libraries. It also install every other
                           dependencies needed to build from the system
                           repositories
      remove               remove (purge) installed ffmpeg-build and delete
                           build folder. It doesn't removes ffmpeg-build
                           package when '--build-package' value is 'no'
      clean                delete source code folder.
      download-only        download all the source code to be used without
                           compile it nor build it
  --source-code-dir=DIR    directory to store the downloaded source code
                           [source-code]
  --build-package=yes|no   build ffmpeg-build package. [yes]
  --package-install=yes|no install ffmpeg-build after the package is build.
                           Ignored when ffmpeg-build package isn't build
                           [yes]
  --prefix=PREFIX          install architecture-independent files in PREFIX
                           (FFmpeg only) [/usr/local]
  --lib-prefix=LIB_PREFIX  libraries instalation build folder (excluding
                           FFmpeg) [/usr/local/ffmpeg_build_libraries]
  --bin-prefix=BIN_PREFIX  binaries instalation build folder (including
                           FFmpeg) when doing a non package install
                           (NOT IMPLEMENTED YET) [ffmpeg_build_binaries]
  -y, --yes                respond yes to all questions
                      
Configuration Options:
  --enable-static=yes|no   enables static libraries [yes]
  --enable-shared=yes|no   enables shared libraries [no]
  --hybrid-build=yes|no    build ffmpeg as static but includes "shared only"
                           codecs too. It ignores both '--enable-static' and
                           '--enable-shared' values
  --existing-source=yes|no ignore existing source code at install action.
                           It's recommended when modifying source code or
                           when 'download-only' action was already
                           executed [no]
  -m, --mode=MODE          configure the script with predefined options
                           overriding the default values
      npkg-build           create a non package static build:
                               --action="install"
                               --package-install="no"
                               --build-package="no"
                               --enable-static="yes"
                               --enable-shared="no"
      npkg-build-adv       create a non package static build with existing
                           source code:
                               --action="install"
                               --package-install="no"
                               --build-package="no"
                               --enable-static="yes"
                               --enable-shared="no"
                               --existing-source="yes"
      npkg-remove          remove a non package static build:
                               --action="remove"
                               --package-install="no"
                               --build-package="no"
      static-install       install a static package build:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --enable-static="yes"
                               --enable-shared="no"
      static-install-adv   install a static package build with existing
                           source code:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --enable-static="yes"
                               --enable-shared="no"
                               --existing-source="yes"
      shared-install       install a shared package build:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --enable-static="no"
                               --enable-shared="yes"
      shared-install-adv   install a shared package build with existing
                           source code:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --enable-static="no"
                               --enable-shared="yes"
                               --existing-source="yes"
      hybrid-install       install a hybrid package build:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --hybrid-build="yes"
      hybrid-install-adv   install a hybrid package build with existing
                           source code:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --hybrid-build="yes"
                               --existing-source="yes"
      full-install         install as package with both static and shared
                           builds:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --enable-static="yes"
                               --enable-shared="yes"
      full-install-adv     install as package with both static and shared
                           builds with existing source code:
                               --action="install"
                               --package-install="yes"
                               --build-package="yes"
                               --enable-static="yes"
                               --enable-shared="yes"
      update-code-only     download and update the source code only:
                               --action="download-only"
                               --existing-source="yes"
      package-remove       remove a package static build:
                               --action="remove"
                               --package-install="yes"
                               --build-package="yes"

Package Options:
  --maintainer=EMAIL       set a custom maintainer on package builds
                           [USER@HOST]

Current libraries to build and install from source code:

  =================  ==============  ============================
   Library            Code Folder     Package Name
  =================  ==============  ============================
   ** Frei0r          frei0r          frei0r-build
   OGG                ogg             libogg-build
   fdk-aac            fdk-aac         fdk-aac-build
   Opus               opus            libopus-build
   ** SoX             soxr-code       libsox-build
   Vorbis             vorbis          libvorbis-build
   Theora             theora          libtheora-build
   VisualOn AAC       vo-aacenc       libvo-aacenc-build
   VisualOn AMR-WB    vo-amrwbenc     libvo-amrwbenc-build
   Flac               flac            libflac-build
   libsndfile         libsndfile      libsndfile-build
   * TwoLAME          twolame         libtwolame-build
   VPX                libvpx          libvpx-build
   x264               x264            libx264-build
   XAVS               xavs            libxavs-build
   FFmpeg             ffmpeg          ffmpeg-build
  =================  ==============  ============================
   
  * Not implemented
 ** Shared or hybrid build required

EOF
    exit 0
}

#Show help message when no parameters
if [ $# -lt 1 ]; then
    show_help $SCRIPT_FILE
fi
while test $# -gt 0; do
    case "$1" in
        -h|--help)
            show_help $SCRIPT_FILE
            ;;
        -a)
            shift
            if test $# -gt 0; then
                NEW_ACTION=$1
            else
                NEW_ACTION=""
            fi
            shift
            ;;
        --action*)
            AUX=`echo "$1" | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--action" ]; then
                NEW_ACTION=$AUX
            fi
            shift
            ;;
        --source-code-dir*)
            "AUX"=`echo "$1" | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--source-code-dir" ]; then
                NEW_SOURCE_DIR=$AUX
            fi
            shift
            ;;
        --prefix*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--prefix" ]; then
                NEW_PREFIX=$AUX
            fi
            shift
            ;;
        --lib-prefix*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--lib-prefix" ]; then
                NEW_LIB_PREFIX=$AUX
            fi
            shift
            ;;
        --bin-prefix*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--bin-prefix" ]; then
                NEW_BIN_PREFIX=$AUX
            fi
            shift
            ;;
        --enable-static*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" = "--enable-static" ]; then
                NEW_ENABLE_STATIC="yes"
            else
                NEW_ENABLE_STATIC=$AUX
            fi
            shift
            ;;
        --enable-shared*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" = "--enable-shared" ]; then
                NEW_ENABLE_SHARED="yes"
            else
                NEW_ENABLE_SHARED=$AUX
            fi
            shift
            ;;
        --hybrid-build*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" = "--hybrid-build" ]; then
                NEW_HYBRID_BUILD="yes"
            else
                NEW_HYBRID_BUILD=$AUX
            fi
            shift
            ;;
        --existing-source*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" = "--existing-source" ]; then
                NEW_EXISTING_SOURCE_CODE="yes"
            else
                NEW_EXISTING_SOURCE_CODE=$AUX
            fi
            shift
            ;;
        --package-install*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" = "--package-install" ]; then
                NEW_PACKAGE_INSTALL="yes"
            else
                NEW_PACKAGE_INSTALL=$AUX
            fi
            shift
            ;;
        -m)
            shift
            if test $# -gt 0; then
                MODE=$1
            else
                MODE=""
            fi
            shift
            ;;
        --mode*)
            AUX=`echo "$1" | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--mode" ]; then
                MODE=$AUX
            fi
            shift
            ;;
        --maintainer*)
            AUX=`echo $1 | sed -e 's/^[^=]*=//g'`
            if [ "$AUX" != "--maintainer" ]; then
                NEW_MAINTAINER=$AUX
            fi
            shift
            ;;
        -y|--yes)
            YES_TO_ALL=1
            shift
            ;;
        *)
            echo "Error: Invalid parameter '$1' found. $HELP_MESSAGE"
            exit 1
            ;;
    esac
done

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Keep sudo alive
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
cat <<EOF

IMPORTANT
=========
  This script require root access to install FFmpeg dependencies from
  repositories and will require you to login if sudo timeout.

EOF
#Ask for sudo admin rights only once to install required packages
sudo -v
#Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

#Validate configuration
#MODE
case $MODE in
    npkg-build)
        ACTION="install"
        PACKAGE_INSTALL="no"
        BUILD_PACKAGE="no"
        ENABLE_STATIC="yes"
        ENABLE_SHARED="no"
        ;;
    npkg-build-adv)
        ACTION="install"
        PACKAGE_INSTALL="no"
        BUILD_PACKAGE="no"
        ENABLE_STATIC="yes"
        ENABLE_SHARED="no"
        EXISTING_SOURCE_CODE="yes"
        ;;
    npkg-remove)
        ACTION="remove"
        PACKAGE_INSTALL="no"
        BUILD_PACKAGE="no"
        ;;
    static-install)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ENABLE_STATIC="yes"
        ENABLE_SHARED="no"
        ;;
    static-install-adv)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ENABLE_STATIC="yes"
        ENABLE_SHARED="no"
        EXISTING_SOURCE_CODE="yes"
        ;;
    shared-install)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ENABLE_STATIC="no"
        ENABLE_SHARED="yes"
        ;;
    shared-install-adv)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ENABLE_STATIC="no"
        ENABLE_SHARED="yes"
        EXISTING_SOURCE_CODE="yes"
        ;;
    hybrid-install)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        HYBRID_BUILD="yes"
        ;;
    hybrid-install-adv)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        HYBRID_BUILD="yes"
        EXISTING_SOURCE_CODE="yes"
        ;;
    full-install)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ENABLE_STATIC="yes"
        ENABLE_SHARED="yes"
        ;;
    full-install-adv)
        ACTION="install"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ENABLE_STATIC="yes"
        ENABLE_SHARED="yes"
        EXISTING_SOURCE_CODE="yes"
        ;;
    update-code-only)
        ACTION="download-only"
        EXISTING_SOURCE_CODE="yes"
        ;;
    package-remove)
        ACTION="remove"
        PACKAGE_INSTALL="yes"
        BUILD_PACKAGE="yes"
        ;;
    "")
        ;;
    *)
        echo "Error: Invalid --mode value. $HELP_MESSAGE"
        exit 1
        ;;
esac
#Assign custom values
if [ "$NEW_DEB_PREFIX" != "" ]; then DEB_PREFIX=$NEW_DEB_PREFIX; fi
if [ "$NEW_LIB_PREFIX" != "" ]; then LIB_PREFIX=$NEW_LIB_PREFIX; fi
if [ "$NEW_BIN_PREFIX" != "" ]; then BIN_PREFIX=$NEW_BIN_PREFIX; fi
if [ "$NEW_ACTION" != "" ]; then ACTION=$NEW_ACTION; fi
if [ "$NEW_SOURCE_DIR" != "" ]; then SOURCE_DIR=$NEW_SOURCE_DIR; fi
if [ "$NEW_ENABLE_SHARED" != "" ]; then ENABLE_SHARED=$NEW_ENABLE_SHARED; fi
if [ "$NEW_ENABLE_STATIC" != "" ]; then ENABLE_STATIC=$NEW_ENABLE_STATIC; fi
if [ "$NEW_HYBRID_BUILD" != "" ]; then HYBRID_BUILD=$NEW_HYBRID_BUILD; fi
if [ "$NEW_PACKAGE_INSTALL" != "" ]; then PACKAGE_INSTALL=$NEW_PACKAGE_INSTALL; fi
if [ "$NEW_BUILD_PACKAGE" != "" ]; then BUILD_PACKAGE=$NEW_BUILD_PACKAGE; fi
if [ "$NEW_MAINTAINER" != "" ]; then MAINTAINER=$NEW_MAINTAINER; fi
if [ "$NEW_EXISTING_SOURCE_CODE" != "" ]; then EXISTING_SOURCE_CODE=$NEW_EXISTING_SOURCE_CODE; fi
#ACTION
case $ACTION in
    install)
        IS_INSTALL=1
        ;;
    remove)
        IS_REMOVE=1
        ;;
    clean)
        IS_CLEAN=1
        ;;
    download-only)
        IS_DOWNLOAD_ONLY=1
        ;;
    "")
        echo "Error: No --action value specified. $HELP_MESSAGE"
        exit 1
        ;;
    *)
        echo "Error: Invalid --action value. $HELP_MESSAGE"
        exit 1
        ;;
esac
#PACKAGE_INSTALL
case $PACKAGE_INSTALL in
    yes)
        IS_PACKAGE_INSTALL=1
        ;;
    no)
        IS_PACKAGE_INSTALL=0
        ;;
    *)
        echo "Error: Invalid --package-install value. $HELP_MESSAGE"
        exit 1
        ;;
esac
#BUILD_PACKAGE
case $BUILD_PACKAGE in
    yes)
        IS_BUILD_PACKAGE=1
        ;;
    no)
        IS_BUILD_PACKAGE=0
        ;;
    *)
        echo "Error: Invalid --build-package value. $HELP_MESSAGE"
        exit 1
        ;;
esac
##PREFIX
#if [ $IS_PACKAGE_INSTALL -eq 1 ] && ( [ $IS_REMOVE -eq 1 ] || [ $IS_INSTALL -eq 1 ] || [ $IS_REMOVE -eq 1 ] ); then
#    if [ ! -d $PREFIX ]; then
#        echo "Error: Invalid --prefix value: Could not found '$PREFIX' folder."
#        exit 1
#    else
#        validate_superuser_write_access "$PREFIX"
#    fi
#fi
#HYBRID_BUILD
case $HYBRID_BUILD in
    yes)
        #Override ENABLE_SHARED and ENABLE_STATIC 
        ENABLE_SHARED="no"
        ENABLE_STATIC="yes"
        HYBRID_SHARED_ON_OFF="ON"
        HYBRID_SHARED_YES_NO="yes"
        HYBRID_SHARED_ENABLED="--enable-shared"
        HYBRID_SHARED_DISABLED=""
        IS_HYBRID=1
        ;;
    no)
        IS_HYBRID=0
        ;;
    *)
        echo "Error: Invalid --hybrid-build value. $HELP_MESSAGE"
        exit 1
        ;;
esac
#ENABLE_SHARED
case $ENABLE_SHARED in
    yes)
        SHARED_ON_OFF="ON"
        SHARED_YES_NO="yes"
        SHARED_ENABLED="--enable-shared"
        SHARED_DISABLED=""
        IS_SHARED=1
        ;;
    no)
        SHARED_ON_OFF="OFF"
        SHARED_YES_NO="no"
        SHARED_ENABLED=""
        SHARED_DISABLED="--disable-shared"
        IS_SHARED=0
        ;;
    *)
        echo "Error: Invalid --enable-shared value. $HELP_MESSAGE"
        exit 1
        ;;
esac
#ENABLE_STATIC
case $ENABLE_STATIC in
    yes)
        STATIC_ON_OFF="ON"
        STATIC_YES_NO="yes"
        STATIC_ENABLED="--enable-static"
        STATIC_DISABLED=""
        IS_STATIC=1
        ;;
    no)
        STATIC_ON_OFF="OFF"
        STATIC_YES_NO="no"
        STATIC_ENABLED=""
        STATIC_DISABLED="--disable-static"
        IS_STATIC=0
        ;;
    *)
        echo "Error: Invalid --enable-static value. $HELP_MESSAGE"
        exit 1
        ;;
esac
#EXISTING_SOURCE_CODE
case $EXISTING_SOURCE_CODE in
    yes)
        SOURCE_CODE_EXISTS=1
        ;;
    no)
        SOURCE_CODE_EXISTS=0
        ;;
    *)
        echo "Error: Invalid --existing-source value. $HELP_MESSAGE"
        exit 1
        ;;
esac

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#ACTION: clean
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
if [ $IS_CLEAN -eq 1 ]; then
#    remove_debs() {
#        #Delete deb files from the directory
#        if [ -d "$1" ]; then
#            validate_write_access "$1"
#            cd "$1"
#            echo "deleting deb files on '$1'..."
#            rm -rf *.deb
#            if [ $# -gt 1 ]; then
#                cd $2
#            else
#                cd ..
#            fi
#        fi
#    }
    
#    #Delete every deb file on source code
#    clean_debs() {
#        #Delete FFmpeg debs
#        remove_debs "ffmpeg"
#    }

    #Clean source code
    if [ -d "$SOURCE_DIR" ]; then
        validate_write_access "$SOURCE_DIR"
        rm -rf "$SOURCE_DIR"
    fi
    echo "Done."
    exit 0
fi

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#ACTION: remove
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
remove_builds() {
    if [ $IS_PACKAGE_INSTALL -eq 1 ]; then
        #Remove ffmpeg-build
        sudo apt-get -y purge ffmpeg-build
    fi
    
    #Remove generated libraries
    if [ -d "$BUILD_DIR" ]; then
        echo "deleting '$BUILD_DIR' folder..."
        $(root_when_needed "$BUILD_DIR") rm -rf "$BUILD_DIR"
    fi
}

if [ $IS_REMOVE -eq 1 ]; then
    remove_builds
    echo "Done."
    exit 0
fi

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#ACTION: install/download-only
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
if [ $IS_INSTALL -eq 1 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
    #======================================
    #Previous steps
    #======================================
    #Check and create main directory, then navigate to it
    if [ -d "$BUILD_DIR" ] && [ $SOURCE_CODE_EXISTS -eq 0 ]; then
cat <<EOF

WARNING
=======
The build folder ('$BUILD_FOLDER') already exists and will be deleted
before continue. If you want to use existing source code then add
'--existing-source' parameter to execute this script.

EOF
        ! confirm "  Do you want to continue anyway? (y/n) " && exit 0
        $(root_when_needed "$BUILD_DIR") rm -rf "$BUILD_DIR"
    fi
    if [ ! -d "$BUILD_DIR" ]; then
        $(root_when_needed "$SCRIPT_DIR") mkdir "$BUILD_DIR" || exit 1
    fi
    cd "$BUILD_DIR"
    
    #Validate install config and display warnings
    if [ $IS_INSTALL -eq 1 ]; then
        #Check for at least one build type
        if [ $IS_SHARED -eq 0 ] && [ $IS_STATIC -eq 0 ]; then
            echo "Error: You need to use at least one build type (shared and/or static)."
            exit 1
        fi
        
        #Check for shared libraries
        if [ $IS_SHARED -eq 0 ] && [ $IS_HYBRID -eq 0 ] && [ $IS_STATIC -eq 1 ]; then
cat <<EOF

WARNING
=======
Frei0r and SORX can't be build as static only and will be excluded
from the build.

EOF
            ! confirm "  Do you want to continue? (y/n) " && exit 0
        fi
    fi

    #Validate source code folder
    if [ $SOURCE_CODE_EXISTS -eq 0 ]; then
        if [ -d "$SOURCE_DIR" ]; then
cat <<EOF

WARNING
=======
The source code folder ('$SOURCE_FOLDER') already exists and will be
deleted to continue. If you want to use existing source code then
add '--existing-source' parameter to execute this script.

EOF
            ! confirm "  Do you want to continue anyway? (y/n) " && exit 0
            $(root_when_needed "$SOURCE_DIR") rm -rf "$SOURCE_DIR" || exit 1
        fi
    else
        echo "Existing source code enabled."
    fi
    
    #Validate and create build folders
    if [ $IS_INSTALL -eq 1 ]; then
        if [ -d "$LIB_PREFIX" ]; then
cat <<EOF

WARNING
=======
The library folder ('$LIB_FOLDER') already exists and will be
deleted to continue.

EOF
            ! confirm "  Do you want to continue? (y/n) " && exit 0
            $(root_when_needed "$LIB_PREFIX") rm -rf "$LIB_PREFIX" || exit 1
        fi
        if [ -d "$FFMPEG_PREFIX" ]; then
cat <<EOF

WARNING
=======
The ffmpeg build folder ('$FFMPEG_FOLDER') already exists and will
be deleted to continue.

EOF
            ! confirm "  Do you want to continue? (y/n) " && exit 0
            $(root_when_needed "$FFMPEG_PREFIX") rm -rf "$FFMPEG_PREFIX" || exit 1
        fi
        if [ -d "$DEB_BUILD_DIR" ]; then
cat <<EOF

WARNING
=======
The ffmpeg build folder ('$DEB_BUILD_FOLDER') already exists and
will be deleted to continue.

EOF
            ! confirm "  Do you want to continue? (y/n) " && exit 0
            $(root_when_needed "$DEB_BUILD_DIR") rm -rf "$DEB_BUILD_DIR" || exit 1
        fi
        
        #Create build folders
        echo "Creating '$LIB_PREFIX' folder..."
        $(root_when_needed "$BUILD_DIR") mkdir "$LIB_PREFIX" || exit 1
        echo "Creating '$FFMPEG_PREFIX' folder..."
        $(root_when_needed "$BUILD_DIR") mkdir "$FFMPEG_PREFIX" || exit 1
        echo "Creating '$DEB_BUILD_DIR' folder..."
        $(root_when_needed "$BUILD_DIR") mkdir "$DEB_BUILD_DIR" || exit 1
    fi
        
    #Create source code folder
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Creating '$SOURCE_DIR' folder..."
        $(root_when_needed "$BUILD_DIR") mkdir "$SOURCE_DIR" || exit 1
    fi
    
    #Validate write access over build folder
    validate_write_access "$SOURCE_DIR"
    echo "Source code folder and build folders ready."
    
    #Adding environment variables
    echo "Adding environment variables for this script only."
    PATH="$LIB_PREFIX/bin:$FFMPEG_PREFIX/bin:$PATH"
    export PATH
    LD_LIBRARY_PATH="$LIB_PREFIX/lib:$FFMPEG_PREFIX/lib:$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH
    
    #Update repository
    echo "Updating repositories..."
    sudo apt-get update || exit 1

    #======================================
    #Install versioning tools
    #======================================
    echo "Install Git and SVN tools"
    #Installl SVN
    sudo apt-get -y install subversion || exit 1
    
    #Install git
    sudo apt-get -y install git || exit 1

    #======================================
    #Get Source Code
    #======================================
    #Navigate to source code folder
    echo "Clone and/or update source code..."
    cd "$SOURCE_DIR"
    
    #--------------------------------------
    #Tools
    #--------------------------------------
    ##Yasm
    #if [ ! -d yasm ]; then
    #    #Get the code from source
    #    #rm -rf yasm-1.2.0
    #    #rm -rf yasm-1.2.0.tar.gz
    #    #wget http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz
    #    #tar xzvf yasm-1.2.0.tar.gz
    #    #mv yasm-1.2.0 yasm
    #    #rm -rf yasm-1.2.0.tar.gz
    #    git clone git://github.com/yasm/yasm.git yasm
    #    if [ ! -d yasm ]; then
    #        echo "Error: Couldn't get 'yasm' source code."
    #        exit 1
    #    fi
    #elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
    #    #Clean and update existing code
    #    cd yasm
    #    make distclean
    #    git pull || exit 1
    #    git mergetool #|| exit 1
    #    cd ..
    #fi

    #--------------------------------------
    #Codecs
    #--------------------------------------
    ##FontConfig
    #if [ ! -d fontconfig ]; then
    #    #Get the code from source
    #    git clone git://anongit.freedesktop.org/fontconfig fontconfig || exit 1
    #    if [ ! -d fontconfig ]; then
    #        echo "Error: Couldn't get 'fontconfig' source code."
    #        exit 1
    #    fi
    #elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
    #    #Clean and update existing code
    #    cd fontconfig
    #    make distclean
    #    git pull || exit 1
    #    git mergetool #|| exit 1
    #    cd ..
    #fi

    #Frei0r
    if [ ! -d frei0r ]; then
        #Get the code from source
        git clone git://code.dyne.org/frei0r.git frei0r || exit 1
        if [ ! -d frei0r ]; then
            echo "Error: Couldn't get 'frei0r' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd frei0r
        #Create or clean Release folder required to build
        if [ -d "$FREI0R_BUILD_DIR" ]; then
            cd "$FREI0R_BUILD_DIR"
            make distclean
            cd ..
            $(root_when_needed "$SOURCE_DIR") rm -rf "$FREI0R_BUILD_DIR"
        fi
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi
    #Create folder required to build
    cd frei0r
    if [ -d "$FREI0R_BUILD_DIR" ]; then
        $(root_when_needed "$SOURCE_DIR") rm -rf "$FREI0R_BUILD_DIR"
    fi
    $(root_when_needed "$SOURCE_DIR") mkdir "$FREI0R_BUILD_DIR" || exit 1
    cd ..

    #Ogg
    if [ ! -d ogg ]; then
        #Get the code from source
        svn co http://svn.xiph.org/trunk/ogg ogg || exit 1
        if [ ! -d ogg ]; then
            echo "Error: Couldn't get 'ogg' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd ogg
        make distclean
        svn update || exit 1
        cd ..
    fi
    
    ##GnuTLS
    #if [ ! -d gnutls ]; then
    #    #Get the code from source
    #    git clone git://gitorious.org/gnutls/gnutls.git gnutls
    #    if [ ! -d gnutls ]; then
    #        echo "Error: Couldn't get 'gnutls' source code."
    #        exit 1
    #    fi
    #elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
    #    #Clean and update existing code
    #    cd gnutls
    #    make distclean
    #    git pull || exit 1
    #    git mergetool #|| exit 1
    #    cd ..
    #fi
    
    #fdk-aac
    if [ ! -d fdk-aac ]; then
        #Get the code from source
        git clone git://github.com/mstorsjo/fdk-aac.git fdk-aac || exit 1
        if [ ! -d fdk-aac ]; then
            echo "Error: Couldn't get 'fdk-aac' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd fdk-aac
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    #Opus
    if [ ! -d opus ]; then
        #Get the code from source
        git clone git://git.xiph.org/opus.git opus || exit 1
        if [ ! -d opus ]; then
            echo "Error: Couldn't get 'opus' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd opus
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    #SoX
    if [ ! -d soxr-code ]; then
        #Get the code from source
        git clone git://git.code.sf.net/p/soxr/code soxr-code || exit 1
        if [ ! -d soxr-code ]; then
            echo "Error: Couldn't get 'soxr-code' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd soxr-code
        #Create or clean Release folder required to build
        if [ -d "$SOX_BUILD_DIR" ]; then
            cd "$SOX_BUILD_DIR"
            make distclean
            cd ..
            $(root_when_needed "$SOURCE_DIR") rm -rf "$SOX_BUILD_DIR"
        fi
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi
    #Create folder required to build
    cd soxr-code
    if [ -d "$SOX_BUILD_DIR" ]; then
        $(root_when_needed "$SOURCE_DIR") rm -rf "$SOX_BUILD_DIR"
    fi
    $(root_when_needed "$SOURCE_DIR") mkdir "$SOX_BUILD_DIR" || exit 1
    cd ..

    #Vorbis
    if [ ! -d vorbis ]; then
        #Get the code from source
        svn co http://svn.xiph.org/trunk/vorbis vorbis || exit 1
        #svn co http://svn.xiph.org/tags/vorbis/libvorbis-1.3.3 vorbis
        if [ ! -d vorbis ]; then
            echo "Error: Couldn't get 'vorbis' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd vorbis
        make distclean
        svn update || exit 1
        cd ..
    fi

    #Theora
    if [ ! -d theora ]; then
        #Get the code from source
        svn co http://svn.xiph.org/trunk/theora theora || exit 1
        if [ ! -d theora ]; then
            echo "Error: Couldn't get 'theora' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd theora
        make distclean
        svn update || exit 1
        cd ..
    fi

    #VisualOn AAC
    if [ ! -d vo-aacenc ]; then
        #Get the code from source
        git clone git://github.com/mstorsjo/vo-aacenc.git vo-aacenc || exit 1
        if [ ! -d vo-aacenc ]; then
            echo "Error: Couldn't get 'vo-aacenc' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd vo-aacenc
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    #VisualOn AMR-WB
    if [ ! -d vo-amrwbenc ]; then
        #Get the code from source
        git clone git://github.com/mstorsjo/vo-amrwbenc.git vo-amrwbenc || exit 1
        if [ ! -d vo-amrwbenc ]; then
            echo "Error: Couldn't get 'vo-amrwbenc' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd vo-amrwbenc
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    #Flac
    if [ ! -d flac ]; then
        #Get the code from source
        git clone git://git.xiph.org/flac.git flac || exit 1
        if [ ! -d flac ]; then
            echo "Error: Couldn't get 'flac' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd flac
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    #libsndfile
    if [ ! -d libsndfile ]; then
        #Get the code from source
        git clone git://github.com/erikd/libsndfile.git libsndfile || exit 1
        if [ ! -d libsndfile ]; then
            echo "Error: Couldn't get 'libsndfile' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd libsndfile
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    ##TwoLAME
    #if [ ! -d twolame ]; then
    #    #Get the code from source
    #    git clone https://github.com/njh/twolame.git twolame || exit 1
    #    if [ ! -d twolame ]; then
    #        echo "Error: Couldn't get 'twolame' source code."
    #        exit 1
    #    fi
    #elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
    #    #Clean and update existing code
    #    cd twolame
    #    make distclean
    #    git pull || exit 1
    #    git mergetool #|| exit 1
    #    cd ..
    #fi

    #VPX
    if [ ! -d libvpx ]; then
        #Get the code from source
        git clone https://chromium.googlesource.com/webm/libvpx || exit 1
        if [ ! -d libvpx ]; then
            echo "Error: Couldn't get 'libvpx' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd libvpx
        make clean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi

    #x264
    if [ ! -d x264 ]; then
        #Get the code from source
        git clone git://git.videolan.org/x264.git x264 || exit 1
        if [ ! -d x264 ]; then
            echo "Error: Couldn't get 'x264' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd x264
        make distclean
        git pull || exit 1
        git merge #|| exit 1
        cd ..
    fi

    #XAVS
    if [ ! -d xavs ]; then
        #Get the code from source
        svn co https://xavs.svn.sourceforge.net/svnroot/xavs/trunk xavs || exit 1
        if [ ! -d xavs ]; then
            echo "Error: Couldn't get 'xavs' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd xavs
        make distclean
        svn update || exit 1
        cd ..
    fi

    #--------------------------------------
    #Apps
    #--------------------------------------
    #FFmpeg
    if [ ! -d ffmpeg ]; then
        #Get the code from source
        git clone git://source.ffmpeg.org/ffmpeg ffmpeg || exit 1
        if [ ! -d ffmpeg ]; then
            echo "Error: Couldn't get 'ffmpeg' source code."
            exit 1
        fi
    elif [ $SOURCE_CODE_EXISTS -eq 0 ] || [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
        #Clean and update existing code
        cd ffmpeg
        make distclean
        git pull || exit 1
        git mergetool #|| exit 1
        cd ..
    fi
    
    if [ $IS_DOWNLOAD_ONLY -eq 1 ]; then
cat <<EOF

The source code has been downloaded and updated successfully.

EOF
        exit 0
    fi
    echo "Done, source code is ready."
    
    #======================================
    #Remove Package and create LIB_PREFIX
    #======================================
    #remove_builds
    
    #======================================
    #Make and Install
    #======================================
    echo "Compiling source code..."
    cd "$SOURCE_DIR"
    
    # Library and include directory variables
    LIB_PREFIX_LIB="$LIB_PREFIX/lib"
    LIB_PREFIX_INCLUDE="$LIB_PREFIX/include"
    LIB_PREFIX_CONFIG="$LIB_PREFIX_LIB/pkgconfig"

    #--------------------------------------
    #Tools
    #--------------------------------------
    #Install autoconf ##
    sudo apt-get -y install autoconf || exit 1

    #Install automake ##
    sudo apt-get -y install automake || exit 1

    #Install autogen ##
    sudo apt-get -y install autogen || exit 1

    #Install cmake ##
    sudo apt-get -y install cmake || exit 1

    #Install build-essential ##
    sudo apt-get -y install build-essential || exit 1

    #============== To create DEB Packages ==============
    #Install debhelper ##
    sudo apt-get -y install debhelper || exit 1

    #Install dh-make ##
    sudo apt-get -y install dh-make || exit 1
    #====================================================

    #Install checkinstall ##
    sudo apt-get -y install checkinstall || exit 1

    #Install GPAC
    sudo apt-get -y install libgpac-dev || exit 1

    #Install Jack Audio Connection Kit
    sudo apt-get -y install libjack-jackd2-dev || exit 1

    #Install Simple DirectMedia Layer
    sudo apt-get -y install libsdl1.2-dev || exit 1

    #Install libtool ##
    sudo apt-get -y install libtool || exit 1

    #Install Video Acceleration API
    sudo apt-get -y install libva-dev || exit 1

    #Install VDPAU
    sudo apt-get -y install libvdpau-dev || exit 1

    #Install X11
    sudo apt-get -y install libx11-dev || exit 1

    #Install X11 misc
    sudo apt-get -y install libxext-dev || exit 1

    #Install X11 misc Fixes
    sudo apt-get -y install libxfixes-dev || exit 1

    #Install pkg-config
    sudo apt-get -y install pkg-config || exit 1

    #Install texi2html
    sudo apt-get -y install texi2html || exit 1
    
    #Install gperf
    sudo apt-get -y install gperf || exit 1

    #Install Yasm
    sudo apt-get -y install yasm || exit 1
    #cd yasm
    #./autogen.sh
    #./configure --prefix="$PREFIX"
    #make
    #checkinstall --pkgname=yasm --pkgversion="$(date +%Y%m%d%H%M)-git" --backup=no --deldoc=yes --fstrans=no --default
    #ldconfig
    #cd ..
    #hash -r

    ##Install doxygen
    #sudo apt-get -y install doxygen

    #--------------------------------------
    #Codecs
    #--------------------------------------
    #Install bzip2
    sudo apt-get -y install bzip2 || exit 1

    #Install Fontconfig
    sudo apt-get -y install fontconfig || exit 1
    #cd fontconfig
    #./autogen.sh --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    #make || exit 1
    #$(root_when_needed "$LIB_PREFIX") make install || exit 1
    #cd ..
    
    #Install Frei0r (shared build only)
    if [ $IS_SHARED -eq 1 ] || [ $IS_HYBRID -eq 1 ]; then
        #sudo apt-get -y install frei0r-plugins
        #sudo apt-get -y install frei0r-plugins-dev
        cd frei0r
        ./autogen.sh
        ./configure --enable-shared=yes --enable-static=$STATIC_YES_NO --prefix="$LIB_PREFIX" || exit 1
        make || exit 1
        $(root_when_needed "$LIB_PREFIX") make install || exit 1
        make distclean
        cd ..
    fi

    #Install Ogg
    #sudo apt-get -y install libogg-dev
    cd ogg
    ./autogen.sh --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..
    
    #Install GnuTLS
    sudo apt-get -y install libgnutls-dev || exit 1
    #cd gnutls
    #make autoreconf
    #./configure --enable-gcc-warnings --enable-gtk-doc --enable-gtk-doc-pdf
    #make
    #make check
    #$(root_when_needed "$LIB_PREFIX") make install
    #cd ..

    #Install libass
    sudo apt-get -y install libass-dev || exit 1

    #Install libbluray
    sudo apt-get -y install libbluray-dev || exit 1

    #Install libcaca
    sudo apt-get -y install libcaca-dev || exit 1

    #Install FreeType
    sudo apt-get -y install libfreetype6-dev || exit 1

    #Install GSM
    sudo apt-get -y install libgsm1-dev || exit 1

    #Install FAAC
    sudo apt-get -y install libfaac-dev || exit 1

    #Install fdk-aac
    cd fdk-aac
    autoreconf -fiv || exit 1
    ./configure --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..
    
    #Install LAME
    sudo apt-get -y install libmp3lame-dev || exit 1
    #cd libmp3lame
    #./configure --enable-nasm $STATIC_DISABLED $SHARED_DISABLED --prefix="$LIB_PREFIX" || exit 1
    #make || exit 1
    #$(root_when_needed "$LIB_PREFIX") make install || exit 1
    #make distclean
    #cd ..

    #Install OpenCORE AMR
    sudo apt-get -y install libopencore-amrnb-dev || exit 1
    sudo apt-get -y install libopencore-amrwb-dev || exit 1

    #Install OpenJPEG
    sudo apt-get -y install libopenjpeg-dev || exit 1

    #Install Opus
    cd opus
    ./autogen.sh || exit 1
    ./configure --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install RTMPDump
    sudo apt-get -y install librtmp-dev || exit 1

    #Install Schroedinger
    sudo apt-get -y install libschroedinger-dev || exit 1

    #Install SoX (shared build only)
    if [ $IS_SHARED -eq 1 ] || [ $IS_HYBRID -eq 1 ]; then
        #sudo apt-get -y install libsox-dev
        cd soxr-code
        #Build folder created on source code get
        rm -rf CMakeCache.txt
        cd "$SOX_BUILD_DIR"
        cmake -DCMAKE_INSTALL_PREFIX:PATH="$LIB_PREFIX" -DCMAKE_BUILD_TYPE=Release .. || exit 1
        make || exit 1
        make test || exit 1
        $(root_when_needed "$LIB_PREFIX") make install || exit 1
        make distclean
        cd ..
        cd ..
    fi

    #Install Speex
    sudo apt-get -y install libspeex-dev || exit 1

    #Install Vorbis
    #sudo apt-get -y install libvorbis-dev
    cd vorbis
    ./autogen.sh --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" --with-ogg="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install Theora
    #sudo apt-get -y install libtheora-dev
    cd theora
    ./autogen.sh --disable-examples --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" --with-ogg="$LIB_PREFIX" --with-vorbis="$LIB_PREFIX" || exit 1
    make || exit 1
    make check || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install VisualOn AAC
    #sudo apt-get -y install libvo-aacenc-dev
    cd vo-aacenc
    autoreconf -fiv || exit 1
    ./configure --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install VisualOn AMR-WB
    #sudo apt-get -y install libvo-amrwbenc-dev
    cd vo-amrwbenc
    autoreconf -fiv || exit 1
    ./configure --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install FLAC
    #sudo apt-get -y install libflac-dev
    cd flac
    ./autogen.sh || exit 1
    ./configure --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" --with-ogg="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..
    
    #Install libsndfile
    #sudo apt-get -y install libsndfile1-dev || exit 1
    cd libsndfile
    ./autogen.sh || exit 1
    # Configure with environment variables
    env \
        PKG_CONFIG_PATH="$LIB_PREFIX_CONFIG" \
        ./configure --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    make check || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install TwoLAME
    sudo apt-get -y install libtwolame-dev || exit 1
    #cd twolame
    #env \
    #    PKG_CONFIG_PATH="$LIB_PREFIX_CONFIG" \
    #    CFLAGS="-w" \
    #    ./autogen.sh --enable-static=$STATIC_YES_NO --enable-shared=$SHARED_YES_NO --prefix="$LIB_PREFIX" || exit 1
    #make || exit 1
    #make check || exit 1
    #$(root_when_needed "$LIB_PREFIX") make install || exit 1
    #cd ..

    #Install VPX
    #sudo apt-get -y install libvpx-dev
    cd libvpx
    ./configure $STATIC_DISABLED $SHARED_ENABLED --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install x264
    cd x264
    ./configure $STATIC_ENABLED $SHARED_ENABLED --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #Install XAVS
    cd xavs
    ./configure $SHARED_ENABLED --disable-asm --prefix="$LIB_PREFIX" || exit 1
    make || exit 1
    $(root_when_needed "$LIB_PREFIX") make install || exit 1
    make distclean
    cd ..

    #InstallXvid
    sudo apt-get -y install libxvidcore-dev || exit 1

    #Install zlib
    sudo apt-get -y install zlib1g-dev || exit 1
    
    echo "All libraries were compiled and build successfully." 

    #--------------------------------------
    #Apps
    #--------------------------------------
    #Install FFmpeg
    sudo ldconfig || exit 1
    hash -r
    cd ffmpeg
    #Non-static only libraries will be removed from config when static builds
    env \
        PKG_CONFIG_PATH="$LIB_PREFIX_CONFIG" \
        ./configure \
        $(echo "$STATIC_DISABLED $SHARED_ENABLED") --prefix="$FFMPEG_PREFIX" \
        --extra-cflags="-I$LIB_PREFIX_INCLUDE" \
        --extra-ldflags="-L$LIB_PREFIX_LIB" \
        --extra-libs="-ldl" \
        --enable-gpl \
        --enable-nonfree \
        --enable-version3 \
        --enable-bzlib \
        --enable-fontconfig \
        $(if [ $IS_SHARED -eq 1 ] || [ $IS_HYBRID -eq 1 ]; then echo "--enable-frei0r"; fi) \
        --enable-gnutls \
        --enable-libass \
        --enable-libbluray \
        --enable-libcaca \
        --enable-libfreetype \
        --enable-libgsm \
        --enable-libmp3lame \
        --enable-libfdk-aac \
        --enable-libfaac \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-libopenjpeg \
        --enable-libopus \
        --enable-librtmp \
        --enable-libschroedinger \
        $(if [ $IS_SHARED -eq 1 ] || [ $IS_HYBRID -eq 1 ]; then echo "--enable-libsoxr"; fi) \
        --enable-libspeex \
        --enable-libtheora \
        --enable-libtwolame \
        --enable-libvo-aacenc \
        --enable-libvo-amrwbenc \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libxavs \
        --enable-libxvid \
        --enable-zlib \
        --enable-x11grab || exit 1
    make || exit 1
    #if [ $IS_PACKAGE_INSTALL -eq 1 ]; then
    #    sudo checkinstall \
    #        --pkgname=ffmpeg-build \
    #        --pkgversion="$(date +%Y%m%d%H%M)-git" \
    #        --maintainer="$MAINTAINER" \
    #        --requires "$PACKAGE_REQUIRES" \
    #        --replaces "$PACKAGE_REPLACES" \
    #        --conflicts "$PACKAGE_CONFLICTS" \
    #        --provides "$PACKAGE_PROVIDES" \
    #        --pakdir "$SCRIPT_DIR" \
    #        --backup=no \
    #        --deldoc=yes \
    #        --fstrans=no \
    #        --addso=yes \
    #        --default || exit 1
    #    sudo ldconfig || exit 1
    #    cd ..
    #else
        $(root_when_needed "$FFMPEG_PREFIX") make install || exit 1
    #fi
    make distclean
    hash -r
    echo "FFmpeg was compiled and build successfully"

    #======================================
    #Final compiling steps
    #======================================
    #Remove unnecesary package
    sudo apt-get -y autoremove
    sudo ldconfig

    #======================================
    #ffmpeg-build package
    #======================================
    if [ $IS_BUILD_PACKAGE -eq 1 ]; then
        echo "Preparing 'ffmpeg-build' to package..."
        #Create package folders
        cd "$DEB_BUILD_DIR"
        TIMESTAMP="$(date +"%Y%m%d%H%M")" || exit 1
        PACKAGE_FOLDER="ffmpeg-build-0~$TIMESTAMP"
        PACKAGE_FILE_WILDCARD="ffmpeg-build_0~$TIMESTAMP*.deb"
        PACKAGE_DIR="$DEB_BUILD_DIR/$PACKAGE_FOLDER"
        PACKAGE_BIN_FOLDER="bin"
        PACKAGE_BIN_DIR="$PACKAGE_DIR/$PACKAGE_BIN_FOLDER"
        PACKAGE_LIB_FOLDER="lib"
        PACKAGE_LIB_DIR="$PACKAGE_DIR/$PACKAGE_LIB_FOLDER"
        PACKAGE_FFMPEG_FOLDER="ffmpeg-bin"
        PACKAGE_FFMPEG_DIR="$PACKAGE_DIR/$PACKAGE_FFMPEG_FOLDER"
        MAKEFILE_COPY_LIBS=""
        $(root_when_needed "$DEB_BUILD_DIR") mkdir "$PACKAGE_FOLDER" || exit 1
        cd "$PACKAGE_DIR"
        $(root_when_needed "$PACKAGE_DIR") mkdir "$PACKAGE_BIN_FOLDER" || exit 1
        $(root_when_needed "$PACKAGE_DIR") mkdir "$PACKAGE_LIB_FOLDER" || exit 1
        $(root_when_needed "$PACKAGE_DIR") mkdir "$PACKAGE_FFMPEG_FOLDER" || exit 1
        
        #Copy FFmpeg binaries and libraries when exists
        cd "$FFMPEG_PREFIX/bin"
        $(root_when_needed "$PACKAGE_FFMPEG_DIR") cp * "$PACKAGE_FFMPEG_DIR" || exit 1
        cd "$FFMPEG_PREFIX/lib"
        $(root_when_needed "$PACKAGE_LIB_DIR") find . -name '*.so*' -exec cp --parents \{\} "$PACKAGE_LIB_DIR" \; || exit 1
        
        #Copy libraries when exists
        cd "$LIB_PREFIX_LIB"
        $(root_when_needed "$PACKAGE_LIB_DIR") find . -name '*.so*' -exec cp --parents \{\} "$PACKAGE_LIB_DIR" \; || exit 1
        
        #Check for shared libraries
        if [ "$(ls -A "$PACKAGE_LIB_DIR")" ]; then
            MAKEFILE_COPY_LIBS="$PACKAGE_LIB_FOLDER/* $INSTALL_DIR/lib"
        fi
        
        #Create package bin scripts
        cd "$PACKAGE_BIN_DIR"
        $(root_when_needed "$PACKAGE_BIN_DIR") bash -c \
"cat <<'EOF' >> 'ffmpeg-build'
#!/bin/sh
BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\"; cd ..; pwd -P)\" || exit 1
env LD_LIBRARY_PATH=\"\$BASE_DIR/lib:\$LD_LIBRARY_PATH\" PATH=\"\$BASE_DIR/ffmpeg-bin:\$PATH\" ffmpeg \$@
EOF" || exit 1
        $(root_when_needed "$PACKAGE_BIN_DIR") bash -c \
"cat <<'EOF' >> 'ffmpeg-build-play'
#!/bin/sh
BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\"; cd ..; pwd -P)\" || exit 1
env LD_LIBRARY_PATH=\"\$BASE_DIR/lib:\$LD_LIBRARY_PATH\" PATH=\"\$BASE_DIR/ffmpeg-bin:\$PATH\" ffplay \$@
EOF" || exit 1
        $(root_when_needed "$PACKAGE_BIN_DIR") bash -c \
"cat <<'EOF' >> 'ffmpeg-build-probe'
#!/bin/sh
BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\"; cd ..; pwd -P)\" || exit 1
env LD_LIBRARY_PATH=\"\$BASE_DIR/lib:\$LD_LIBRARY_PATH\" PATH=\"\$BASE_DIR/ffmpeg-bin:\$PATH\" ffprobe \$@
EOF" || exit 1
        $(root_when_needed "$PACKAGE_BIN_DIR") bash -c \
"cat <<'EOF' >> 'ffmpeg-build-server'
#!/bin/sh
BASE_DIR=\"\$(cd \"\$(dirname \"\$0\")\"; cd ..; pwd -P)\" || exit 1
env LD_LIBRARY_PATH=\"\$BASE_DIR/lib:\$LD_LIBRARY_PATH\" PATH=\"\$BASE_DIR/ffmpeg-bin:\$PATH\" ffserver \$@
EOF" || exit 1
        #Make scripts executable
        $(root_when_needed "$PACKAGE_BIN_DIR") chmod a+x *
        
        #Create profile.d script
        cd "$PACKAGE_DIR"
        $(root_when_needed "$PACKAGE_DIR") bash -c \
"cat <<'EOF' >> ffmpeg-build.sh
PATH=\"/opt/ffmpeg-build/bin:\$PATH\"
EOF" || exit 1

        #Create DEB package base files
        $(root_when_needed "$PACKAGE_DIR") dh_make \
            -s \
            -e "$MAINTAINER" \
            --createorig \
            -y || exit 1
        cd "debian"
        $(root_when_needed "$PACKAGE_DIR/debian") bash -c \
"cat <<'EOF' >> ffmpeg-build.install
$PACKAGE_BIN_FOLDER/* $INSTALL_DIR/bin
$PACKAGE_FFMPEG_FOLDER/* $INSTALL_DIR/ffmpeg-bin
ffmpeg-build.sh etc/profile.d
$MAKEFILE_COPY_LIBS
EOF" || exit 1

        #Build package
        cd "$PACKAGE_DIR"
        $(root_when_needed "$PACKAGE_DIR") dpkg-buildpackage -rfakeroot -us -uc || exit 1
        
        #Install package
        if [ $IS_PACKAGE_INSTALL -eq 1 ]; then
            cd "$DEB_BUILD_DIR"
            sudo dpkg -i $PACKAGE_FILE_WILDCARD || exit 1
        fi
    fi

    #Display results
cat <<EOF

RESULTS
=======
  FFmpeg and it's codecs were build successfully
EOF

    if  [ $IS_BUILD_PACKAGE -eq 1 ]; then
cat <<EOF
  ffmpeg-build was build successfully
EOF
        if [ $IS_PACKAGE_INSTALL -eq 1 ]; then
cat <<EOF

  You need to restart to complete ffmpeg-build the installation. This is
  needed to make 'ffmpeg-build', 'ffmpeg-build-play', 'ffmpeg-build-probe'
  and 'ffmpeg-build-server' commands visible from terminal.

EOF
        fi
    fi
    
    #Display final messages
    if [ $IS_STATIC -eq 1 ] && [ $IS_SHARED -eq 0 ]; then
cat <<EOF
  
  The library folder is safe to delete because it is a static only build,
  but remember to move ffmpeg bin files before doing that.
    '$LIB_PREFIX'

EOF
    fi
    
    #Exit source code folder
    cd "$SCRIPT_DIR"
    echo "Done."
    echo ""
    exit 0
fi