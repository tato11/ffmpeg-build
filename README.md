```
Description:
  This script will create ffmpeg-build package by compile ffmpeg and it's
  codecs from source code (downloaded from the projects repositories master
  branch). It can also delete the downloaded source code and generated deb
  files by using the 'clean' action.
  
  ffmpeg-build package is a FFmpeg wrapper that installs on
  '/opt/ffmpeg-build' directory isolating it from system package ecosystem
  so there are no broken packages in any way.

  It will need to install the following packages in order to execute:

    subversion, git, autoconf, automake, autogen, cmake, build-essential,
    checkinstall, debhelper, dh-make, libgpac-dev, libjack-jackd2-dev,
    libsdl1.2-dev, libtool, libva-dev, libvdpau-dev, libx11-dev,
    libxext-dev, libxfixes-dev, pkg-config, texi2html, gperf, yasm, bzip2,
    fontconfig, libgnutls-dev, libass-dev, libbluray-dev, libcaca-dev,
    libfreetype6-dev, libgsm1-dev, libfaac-dev, libmp3lame-dev,
    libopencore-amrnb-dev, libopencore-amrwb-dev, libopenjpeg-dev,
    librtmp-dev, libschroedinger-dev, libspeex-dev, libtwolame-dev,
    libxvidcore-dev, zlib1g-dev

  It will also create 'ffmpeg-build_build' directory on the same directory
  this script is located to store all the files it generates as well as the
  source code it downloads:
    'ffmpeg-build_build/codecs'      stores codec libraries and binaries
    'ffmpeg-build_build/ffmpeg'      stores FFmpeg libraries and binaries
    'ffmpeg-build_build/package'     stores all related to the package
                                     generation process including the
                                     package itself
    'ffmpeg-build_build/source-code' stores any codec source code downloaded
                                     from each repository as well as any
                                     other downloaded source code

Usage:
  ./FFmpeg_build_script.sh [options]
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
      clean                delete source code folder
      download-only        download all the source code to be used without
                           compile it nor build it
  --source-code-dir=DIR    directory to store the downloaded source code
                           [source-code]
  --build-package=yes|no   build ffmpeg-build package [yes]
  --package-install=yes|no install ffmpeg-build after the package is build.
                           Ignored when ffmpeg-build package isn't build
                           [yes]
  --maintainer=MAINTAINER  specifies who is the maintainer of the created
                           package [user@host]
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
   *** VisualOn AAC   vo-aacenc       libvo-aacenc-build
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


Some libraries were removed since FFmpeg doesn't support those libraries
anymore:

  =================  ==============  ============================
   Library            Code Folder     Package Name
  =================  ==============  ============================
   VisualOn AAC       vo-aacenc       libvo-aacenc-build
  =================  ==============  ============================
```
