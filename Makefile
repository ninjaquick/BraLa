export PROJECT_NAME     = BraLa
export AUTHOR           = David Herberth
export DESCRIPTION      = A Minecraft SMP Client written in D
export VERSION          =
export LICENSE          = GPLv3

DCFLAGS_IMPORT      = -Ibrala/ -Isrc/d/derelict3/import -Isrc/d/glamour -Isrc/d/gl3n/ \
			-Isrc/d/ -Isrc/d/openssl/ -Isrc/d/glfw/ -Isrc/d/nbd/

include command.make

ifeq ($(OS),"Windows")
	DCFLAGS_LINK =	$(LDCFLAGS) $(LINKERFLAG)-lssl $(LINKERFLAG)-lcrypto \
			$(LINKERFLAG)-L$(CBUILD_PATH)$(PATH_SEP)glfw$(PATH_SEP)src \
			$(LINKERFLAG)-lglfw3.lib $(LINKERFLAG)-lopengl32.lib $(LINKERFLAG)-luser32.lib
else ifeq ($(OS),"MinGW")
	DCFLAGS_LINK =  $(LDCFLAGS) $(LIB_PREFIX)$(PATH_SEP)libssl.lib \
			$(LIB_PREFIX)$(PATH_SEP)libcrypto.lib \
			$(CBUILD_PATH)$(PATH_SEP)glfw$(PATH_SEP)src$(PATH_SEP)glfw3.lib
else
	DCFLAGS_LINK = 	$(LDCFLAGS) $(LINKERFLAG)-lssl $(LINKERFLAG)-lcrypto \
			$(LINKERFLAG)-Lbuild/glfw/src \
			`env PKG_CONFIG_PATH=./build/glfw/src pkg-config --static --libs glfw3 | sed -e "s/-L/-L-L/g;s/-l/-L-l/g"`
endif

ifeq ($(DC),ldc2)
	ADDITIONAL_FLAGS = -d-version=Derelict3 -d-version=gl3n -d-version=stb -d-debug -unittest -g -gc
else ifeq ($(DC),gdc)
	ADDITIONAL_FLAGS = -fversion=Derelict3 -fversion=gl3n -fversion=stb -fdebug -g -fdebug-c
else
	ADDITIONAL_FLAGS = -version=Derelict3 -version=gl3n -version=stb -debug -g -gc
endif


DERELICT_DIR = src$(PATH_SEP)d$(PATH_SEP)derelict3$(PATH_SEP)import$(PATH_SEP)derelict

OBJDIRS		     = $(DBUILD_PATH)$(PATH_SEP)brala \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)arsd \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)derelict3 \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)gl3n \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)glamour \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)openssl \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)std \
			$(DBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)d$(PATH_SEP)nbd \
			$(CBUILD_PATH)$(PATH_SEP)src$(PATH_SEP)c \
			bin

DSOURCES             = $(call getSource,brala,d)
DOBJECTS             = $(patsubst %.d,$(DBUILD_PATH)$(PATH_SEP)%$(EXT),   $(DSOURCES))

DSOURCES_GL3N	     = $(call getSource,src$(PATH_SEP)d$(PATH_SEP)gl3n$(PATH_SEP)gl3n,d)
DOBJECTS_GL3N	     = $(patsubst %.d,$(DBUILD_PATH_GL3N)$(PATH_SEP)%$(EXT),   $(DSOURCES_GL3N))

DSOURCES_DERELICT    =  \
		       $(call getSource,$(DERELICT_DIR)$(PATH_SEP)opengl3,d) \
		       $(call getSource,$(DERELICT_DIR)$(PATH_SEP)util,d)
DOBJECTS_DERELICT    = $(patsubst %.d,$(DBUILD_PATH_GLAMOUR)$(PATH_SEP)%$(EXT),   $(DSOURCES_DERELICT))

DSOURCES_GLAMOUR     = $(call getSource,src$(PATH_SEP)d$(PATH_SEP)glamour$(PATH_SEP)glamour,d)
DOBJECTS_GLAMOUR     = $(patsubst %.d,$(DBUILD_PATH_GLAMOUR)$(PATH_SEP)%$(EXT),   $(DSOURCES_GLAMOUR))

DSOURCES_OTHER	     = $(call getSource,src$(PATH_SEP)d$(PATH_SEP)arsd,d) $(call getSource,src$(PATH_SEP)d$(PATH_SEP)std,d) \
			src$(PATH_SEP)d$(PATH_SEP)nbd$(PATH_SEP)nbt.d
DOBJECTS_OTHER       = $(patsubst %.d,$(DBUILD_PATH_OTHER)$(PATH_SEP)%$(EXT),   $(DSOURCES_OTHER))

CSOURCES             = src$(PATH_SEP)c$(PATH_SEP)stb_image.c $(call getSource,src$(PATH_SEP)c$(PATH_SEP)nbt,c)
COBJECTS             = $(patsubst %.c,$(CBUILD_PATH)$(PATH_SEP)%$(EXT),   $(CSOURCES))


all: glfw brala
#all: brala

.PHONY: clean

brala: buildDir $(COBJECTS) $(DOBJECTS) $(DOBJECTS_GL3N) $(DOBJECTS_DERELICT) $(DOBJECTS_GLAMOUR) $(DOBJECTS_OTHER)
	$(DC) $(DCFLAGS_LINK) $(COBJECTS) $(DOBJECTS) $(DOBJECTS_GL3N) $(DOBJECTS_GLAMOUR) $(DOBJECTS_DERELICT) \
	$(DOBJECTS_OTHER) $(DCFLAGS) $(OUTPUT)bin$(PATH_SEP)bralad

glfw:
	$(MKDIR) $(CBUILD_PATH)$(PATH_SEP)glfw
ifeq ($(OS),"MinGW")
	cd $(CBUILD_PATH)$(PATH_SEP)glfw && \
	cmake -G "MSYS Makefiles" -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF ..$(PATH_SEP)..$(PATH_SEP)src$(PATH_SEP)c$(PATH_SEP)glfw
	cd $(CBUILD_PATH)$(PATH_SEP)glfw && $(MAKE) $(MFLAGS)
	cd $(CBUILD_PATH)$(PATH_SEP)glfw$(PATH_SEP)src && echo "..\..\..\$(IMPLIB) /s glfw3.lib glfw3.dll && exit;" | cmd
else
	cd $(CBUILD_PATH)$(PATH_SEP)glfw && \
	cmake -DBUILD_SHARED_LIBS=OFF -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF ..$(PATH_SEP)..$(PATH_SEP)src$(PATH_SEP)c$(PATH_SEP)glfw
	cd $(CBUILD_PATH)$(PATH_SEP)glfw && $(MAKE) $(MFLAGS)
endif


# create object files
$(DBUILD_PATH)$(PATH_SEP)%$(EXT) : %.d
	$(DC) $(DCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(DBUILD_PATH_GL3N)$(PATH_SEP)%$(EXT) : %.d
	$(DC) $(DCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(DBUILD_PATH_DERELICT)$(PATH_SEP)%$(EXT): %.d
	$(DC) $(DCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(DBUILD_PATH_GLAMOUR)$(PATH_SEP)%$(EXT) : %.d
	$(DC) $(DCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(DBUILD_PATH_OTHER)$(PATH_SEP)%$(EXT) : %.d
	$(DC) $(DCFLAGS) $(DCFLAGS_IMPORT) $(ADDITIONAL_FLAGS) -c $< $(OUTPUT)$@

$(CBUILD_PATH)$(PATH_SEP)%$(EXT) : %.c
ifeq ($(OS),"MinGW")
	$(CC) $(CFLAGS) -c $< -o$@
else
	$(CC) $(CFLAGS) -c $< -o $@
endif

buildDir: $(OBJDIRS)

$(OBJDIRS) :
	$(MKDIR) $@

clean:
	$(RM) build$(PATH_SEP)brala

clean-all:
	$(RM) build