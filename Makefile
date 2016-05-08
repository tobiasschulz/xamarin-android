V             ?= 0
CONFIGURATION = Debug
MSBUILD       = xbuild /p:Configuration=$(CONFIGURATION) $(MSBUILD_ARGS)

ifneq ($(V),0)
MONO_OPTIONS += --debug
MSBUILD      += /v:d
endif

ifneq ($(MONO_OPTIONS),)
export MONO_OPTIONS
endif

all:
	$(MSBUILD)

prepare:
	git submodule update --init --recursive
	nuget restore
	(cd external/Java.Interop && nuget restore)

clean:
	$(MSBUILD) /t:Clean

git-reset: git-reset-submodules
	git clean -xdf
	git reset --hard

git-reset-submodules:
	(cd external/mono && git reset --hard && git clean -xdf)
	(cd external/Java.Interop && git reset --hard && git clean -xdf)

git-update-submodules: git-reset-submodules
	git submodule update --init --recursive
	nuget restore
	(cd external/Java.Interop && git pull origin master && nuget restore)

fix-linux:
	cp Configuration.Override.props.in Configuration.Override.props
	sed -i 's@= Release.AnyCPU@= Release|Any CPU@gm' Xamarin.Android.sln
	sed -i 's@LINUX_JAVA_INCLUDE_DIRS          = /usr/lib/jvm/default-java/include/@LINUX_JAVA_INCLUDE_DIRS          = /usr/lib/jvm/default-java/include@gm' external/Java.Interop/build-tools/scripts/jdk.mk
	sed -i 's@LINUX_JAVA_JNI_OS_INCLUDE_DIR    = ..DESKTOP_JAVA_JNI_INCLUDE_DIR./linux@LINUX_JAVA_JNI_OS_INCLUDE_DIR    = $(DESKTOP_JAVA_JNI_INCLUDE_DIR)/include/linux@gm' external/Java.Interop/build-tools/scripts/jdk.mk
	sed -i 's@rm src/Java.Runtime.Environment/Java.Runtime.Environment.dll.config@rm -f src/Java.Runtime.Environment/Java.Runtime.Environment.dll.config@gm' external/Java.Interop/Makefile

full-java-interop:
	(cd external/Java.Interop && nuget restore && make all)
	mkdir -p bin/$(CONFIGURATION)/bin
	mkdir -p bin/$(CONFIGURATION)/lib/mandroid
	rsync -av external/Java.Interop/bin/$(CONFIGURATION)/ bin/$(CONFIGURATION)/lib/mandroid/
	( \
		echo '#!/bin/bash' \
		echo 'DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"' \
		echo '' \
	) > bin/$(CONFIGURATION)/bin/generator
	chmod +x bin/$(CONFIGURATION)/bin/generator

all-linux: fix-linux full-java-interop all
	cp ./src/Xamarin.Android.Build.Tasks/*.targets bin/$(CONFIGURATION)/lib/xbuild/Xamarin/Android/

all-debian: build-dep-debian all-linux

build-dep-debian:
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	(echo "deb http://download.mono-project.com/repo/debian wheezy main"; echo "deb-src http://download.mono-project.com/repo/debian wheezy main") | sudo tee /etc/apt/sources.list.d/mono-xamarin.list
	(echo "deb http://download.mono-project.com/repo/debian beta main";echo "deb-src http://download.mono-project.com/repo/debian beta main") | sudo tee /etc/apt/sources.list.d/mono-xamarin-beta.list
	sudo apt update
	sudo apt install mono-devel referenceassemblies-pcl
	sudo apt-get build-dep mono

