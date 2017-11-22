#ifndef TOOL_FUNC_H_
#define TOOL_FUNC_H_

typedef long long int my_t;

typedef struct {
	my_t x;
	my_t y;
	my_t vx;
	my_t vy;
	my_t d;
	my_t ss;
	int eid;
	int dead;
} signal;

typedef struct {
	my_t x1;
	my_t y1;
	my_t x2;
	my_t y2;
	int bnum, fnum;
} line;

typedef struct {
	my_t x;
	my_t y;
} node;

typedef struct {
	int inodes[100], isize;
	my_t x, y, radius;
} polygon;

my_t dist(my_t x1, my_t y1, my_t x2, my_t y2);
double veclen(my_t vx, my_t vy);
int compare(my_t i, my_t j);

#endif
