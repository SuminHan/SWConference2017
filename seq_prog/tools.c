#include "tools.h";
#include <math.h>

my_t dist(my_t x1, my_t y1, my_t x2, my_t y2) {
	my_t dx = x2 - x1;
	my_t dy = y2 - y1;
	if (dx == 0) {
		return abs(dy);
	}
	if (dy == 0) {
		return abs(dx);
	}
	return (my_t)sqrtl((long double)(dx*dx + dy*dy));
}

double veclen(my_t vx, my_t vy) {
	return (my_t)sqrtl((long double)(vx*vx + vy*vy));
}

int compare(my_t i, my_t j) {
	return i < j;
}
