# 
# Copyright (c) 2013 No Face Press, LLC
# License http://opensource.org/licenses/mit-license.php MIT License
#

#This makefile is used to test the other Makefiles


PROG = counter-service
SRC = counter-service.c

FUNC_LIB = functions functions_map
FUNC_LIB_SRC = functions.c functions_map.c

DEP_HEADERS = functions_map.h

TOP = libhttp-1.8/
CIVETWEB_LIB = libcivetweb.a

CFLAGS = -I$(TOP)/include $(COPT) -g
LIBS = -lpthread

include $(TOP)/resources/Makefile.in-os

ifeq ($(TARGET_OS),LINUX) 
	LIBS += -ldl
endif

all: $(PROG)

$(PROG): $(CIVETWEB_LIB) $(SRC) $(FUNC_LIB_SRC) $(DEP_HEADERS)
	$(CC) -o $@ $(CFLAGS) $(LDFLAGS) $(SRC) $(FUNC_LIB_SRC) $(CIVETWEB_LIB) $(LIBS)

$(CIVETWEB_LIB):
	$(MAKE) -C $(TOP) clean lib
	cp $(TOP)/$(CIVETWEB_LIB) .

clean:
	rm -f $(CIVETWEB_LIB) $(PROG) $(FUNC_LIB)

.PHONY: all clean
