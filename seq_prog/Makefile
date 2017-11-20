CC = gcc -std=c99
RM = rm -f
CFLAGS = -O2 -fomit-frame-pointer -c

BUILD = prog
OBJS = prog.o tools.o

.PHONY: all clean

all: $(BUILD)
clean: ; $(RM) *.o $(BUILD)
prog: $(OBJS) ; $(CC) -o $@ $^ -lm

$(OBJS): $($@:.o=.c) tools.h Makefile

.c.o: ; $(CC) $(CFLAGS) -o $@ $< -lm
