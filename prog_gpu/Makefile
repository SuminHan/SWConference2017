CC = nvcc
RM = rm -f

BUILD = prog

.PHONY: all clean

all: $(BUILD)
clean: ; $(RM) *.o $(BUILD)
prog:  ; $(CC) -o $@ kernel.cu

