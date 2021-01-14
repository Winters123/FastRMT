PREFIX=/usr/local
BINDIR=$(DESTDIR)$(PREFIX)/bin

CC=gcc
CFLAGS=-fPIC -O3 -Wall -I../modules/mqnic
LDFLAGS=-shared

TARGET = mqnic.so

all: $(TARGET)

mqnic.so: mqnic.c
	$(CC) $(CFLAGS) $(LDFLAGS) mqnic.c -o $(TARGET)



