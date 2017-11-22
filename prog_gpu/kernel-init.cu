#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "tools.h"

#include <time.h>

#define N 172032 //131072
#define M 672
#define THRESHOLD 100000
#define GSIZE 1000
#define PNTSIZE 300
#define AUTO_END 10
#define ORTHO 80000
#define RADIUS 1500
#define RADSCALE 1000000000
#define LINE_SIZE 0.3

#define NCOMPASS 360

#define d2r(deg) (deg * PI / 180.0)
#define kill(s) (s->dead = true)

#define PI 3.14159265358979323846

#define MAPX 1273623389 
#define MAPY 363706170

#define True 1
#define False 0

#define DELIM "\t"

int nnum, bnum, fnum;
int point_mode = 0;

int width = 800, height = 800;
signal sig[N];
my_t compass[NCOMPASS];
int count[NCOMPASS];
int selection_mode = 0; //generator: 0, detector: 1

clock_t total_testing_time = 0;

node *Nodes;
polygon *Buildings;
polygon *Forests;

my_t mapx = 0; //1273623389;
my_t mapy = 0; //363706170;

line ga;
int toggle[10];

void load_file();
void clean_up();
void initialize();

__global__ void signal_calculation(signal *signal_list,
	const node *node_list, const polygon *building_list, const polygon *forest_list, const line *gtoa) {
	my_t gx = gtoa->x1;
	my_t gy = gtoa->y1;
	my_t ax = gtoa->x2;
	my_t ay = gtoa->y2;
	my_t zx, zy;
	int i = threadIdx.x + (blockIdx.x * blockDim.x);

	my_t px, py, test, tdist = 0, kdist = 0;
	signal sigref, sigblk;
	bool possible;

	signal *si = &signal_list[i];

	int autoend = -1;
	while (!si->dead && ++autoend < AUTO_END) {
		si->d = si->vy*si->x - si->vx*si->y;

		// case of detection
		possible = false;
		my_t d = (-si->vy*ax + si->vx*ay + si->d) / RADSCALE;
		if (-RADIUS <= d && d <= RADIUS) {
			if (si->vx != 0) {
				px = ax + (d*si->vy / RADSCALE);
				test = (px - si->x) ^ si->vx;
			}
			else {
				py = ay - (d*si->vx / RADSCALE);
				test = (py - si->y) ^ si->vy;
			}

			if (test > 0) {
				possible = true;
				zx = (si->x - ax);
				zy = (si->y - ay);
				tdist = zx*zx + zy*zy;
			}
		}


		// reflection test
		int n1, n2;
		int j, k;
		my_t test, kdist;
		my_t lx1, ly1, lx2, ly2;
		my_t Tnx, Tny, Td, pr;

		sigref.dead = true;
		int eid;

		for (j = 0; j < gtoa->bnum; j++) {
			// calculate reflection
			const polygon *p = &building_list[j];

			d = ((-si->vy)*p->x + (si->vx)*p->y + si->d) / RADSCALE;
			pr = p->radius;
			//possibly blocked if...
			if (-pr <= d && d <= pr)
			{
				for (k = 0; k < p->isize - 1; k++)
				{
					eid = 100 * i + k;
					if (si->eid == eid) continue;
					n1 = p->inodes[k];
					n2 = p->inodes[k + 1];

					lx1 = node_list[n1].x;
					ly1 = node_list[n1].y;
					lx2 = node_list[n2].x;
					ly2 = node_list[n2].y;

					Tnx = -si->vy;
					Tny = si->vx;
					Td = -(-si->vy*si->x + si->vx*si->y);
					my_t tb = Tnx*(lx2 - lx1) + Tny*(ly2 - ly1);

					if (tb == 0) { // parallel
						continue;
					}

					my_t t = -(Tnx*lx1 + Tny*ly1 + Td);
					if (t == 0 || t == tb) {
						continue;
					}
					if ((0 < t && t < tb) || (tb < t && t < 0)) {
						my_t px = lx1 + t*(lx2 - lx1) / tb;
						my_t py = ly1 + t*(ly2 - ly1) / tb;

						if (si->vx != 0) {
							test = (px - si->x) ^ si->vx;
						}
						else {
							test = (py - si->y) ^ si->vy;
						}

						if (test > 0) {
							zx = (si->x - px);
							zy = (si->y - py);
							kdist = zx*zx + zy*zy;
							if (kdist < 10) continue;
							if (sigref.dead || sigref.ss > kdist) { //if marked as alive
								my_t lnx = -(ly2 - ly1);
								my_t lny = (lx2 - lx1);
								my_t nv = lnx*si->vx + lny*si->vy;
								sigref.x = px;
								sigref.y = py;
								sigref.vx = si->vx - 2 * nv * lnx / (lnx*lnx + lny*lny);
								sigref.vy = si->vy - 2 * nv * lny / (lnx*lnx + lny*lny);
								sigref.ss = kdist;
								sigref.eid = eid;
								sigref.dead = false;
							}
						}
					}
				}
			}
		}

		// blocking test
		sigblk.dead = false;
		for (i = 0; i < gtoa->fnum; i++) {
			// calculate reflection
			const polygon *p = &forest_list[i];
			d = ((-si->vy)*p->x + (si->vx)*p->y + si->d) / RADSCALE;
			pr = p->radius;
			//possibly blocked if...
			if (-pr <= d && d <= pr)
			{
				for (k = 0; k < p->isize - 1; k++)
				{
					n1 = p->inodes[k];
					n2 = p->inodes[k + 1];

					lx1 = node_list[n1].x;
					ly1 = node_list[n1].y;
					lx2 = node_list[n2].x;
					ly2 = node_list[n2].y;

					Tnx = -si->vy;
					Tny = si->vx;
					Td = -(-si->vy*si->x + si->vx*si->y);//sigin->d;
														 // p' = p1 + t(p2-p1), T(dot)p' = 0
														 // t = -(T(dot)p1) / (T(dot)(p2 - p1))
					my_t tb = Tnx*(lx2 - lx1) + Tny*(ly2 - ly1);

					if (tb == 0) { // parallel
						continue;
					}

					my_t t = -(Tnx*lx1 + Tny*ly1 + Td);
					if (t == 0 || t == tb) continue;
					if ((0 < t && t < tb) || (tb < t && t < 0)) {
						my_t px = lx1 + t*(lx2 - lx1) / tb;
						my_t py = ly1 + t*(ly2 - ly1) / tb;

						if (si->vx != 0) {
							test = (px - si->x) ^ si->vx;
						}
						else {
							test = (py - si->y) ^ si->vy;
						}

						if (test > 0) {
							zx = (si->x - px);
							zy = (si->y - py);
							kdist = zx*zx + zy*zy;
							if (!sigblk.dead || sigblk.ss > kdist) { //if marked as alive
																	 //printf("kdist = %lld\n", kdist);
								sigblk.x = px;
								sigblk.y = py;
								sigblk.ss = kdist;
								sigblk.dead = true;
							}
						}
					}
				}
			}
		}

		if (!sigref.dead) {
			if (sigblk.dead) {
				if (possible && tdist < sigref.ss && tdist < sigblk.ss) {
					si->ss += sqrt((float)tdist);
					break;
				}
				if (sigref.ss < sigblk.ss) {
					sigref.ss = sqrt(float(sigref.ss));
					sigref.ss += si->ss;
					*si = sigref;
					continue;
				}
				else {
					kill(si);
					break;
				}
			}
			else {
				if (possible && tdist < sigref.ss) {
					si->ss += sqrt((float)tdist);
					break;
				}
				else {
					sigref.ss = sqrt(float(sigref.ss));
					sigref.ss += si->ss;
					*si = sigref;
					continue;
				}
			}
		}
		else {
			if (sigblk.dead) {
				if (possible && tdist < sigblk.ss) {
					si->ss += sqrt((float)tdist);
					break;
				}
				else {
					kill(si);
					break;
				}
			}
		}

		if (possible)
			si->ss += sqrt((float)tdist);
		else
			kill(si);
		break;
	}
	if (autoend == AUTO_END) {
		kill(si);
	}
}

////////////////// cuda
signal *dev_signals;
node *dev_nodes;
polygon *dev_buildings, *dev_forests;
line *dev_gtoa;

void freeCudaMemory() {
	cudaFree(dev_signals);
	cudaFree(dev_nodes);
	cudaFree(dev_buildings);
	cudaFree(dev_forests);
	cudaFree(dev_gtoa);
}

cudaError_t allocateCudaMemory() {
	cudaError_t cudaStatus;

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}


	// Allocate GPU buffers for three vectors (two input, one output).
	cudaStatus = cudaMalloc((void**)&dev_gtoa, sizeof(line));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_signals, N * sizeof(signal));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_nodes, nnum * sizeof(node));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	// Copy input vectors from host memory to GPU buffers.	
	cudaStatus = cudaMemcpy(dev_nodes, Nodes, nnum * sizeof(node), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_buildings, bnum * sizeof(polygon));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}


	cudaStatus = cudaMemcpy(dev_buildings, Buildings, bnum * sizeof(polygon), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_forests, fnum * sizeof(polygon));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMemcpy(dev_forests, Forests, fnum * sizeof(polygon), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}


Error:
	return cudaStatus;
}

// Helper function for using CUDA to add vectors in parallel.
cudaError_t signalCalcWithCuda()
{
	clock_t tic = clock();
	cudaError_t cudaStatus;

	long double r;

	for (int i = 0; i < N; i++) {
		signal *si = &sig[i];
		r = d2r(360.0 * i / (long double)N);
		si->x = ga.x1;
		si->y = ga.y1;
		si->vx = cosl(r) * RADSCALE;
		si->vy = sinl(r) * RADSCALE;
		si->ss = 0;
		si->dead = false;
		si->eid = -1;
	}

	// Copy input vectors from host memory to GPU buffers.
	cudaStatus = cudaMemcpy(dev_signals, &sig, N * sizeof(signal), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	cudaStatus = cudaMemcpy(dev_gtoa, &ga, sizeof(line), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	// Launch a kernel on the GPU with one thread for each element.
	signal_calculation << <M, N / M >> >(dev_signals, dev_nodes, dev_buildings, dev_forests, dev_gtoa);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "signal_calculation launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching signal_calculation!\n", cudaStatus);
		goto Error;
	}

	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(sig, dev_signals, N * sizeof(signal), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

Error:
	clock_t toc = clock();

	total_testing_time += toc - tic;
	return cudaStatus;
}

void convertToCompass() {
	int i, sidx;
	double sum;

	for (i = 0; i < NCOMPASS; i++) {
		compass[i] = 0;
		count[i] = 0; //initialzie
	}

	int deg;
	for (i = 0; i < N; i++) {
		deg = (int)(atan2(-sig[i].vy, -sig[i].vx) * 180 / PI);
		if (deg < 0) deg += 360;
		sidx = NCOMPASS * deg / 360;

		if (!sig[i].dead) {
			compass[sidx] = 1000000000 / sig[i].ss;
			count[sidx] = 1;
		}
		//compass[hidx]
	}
	for (i = 0; i < NCOMPASS; i++) {
		if(count[i] != 0)
			compass[i] /= count[i];
	}
}

void printOutput(){
	fprintf(stdout, "[");
	int i;
	for (i = 0; i < NCOMPASS; i++) {
		if (i == NCOMPASS - 1) {
			fprintf(stdout, "%d", compass[i]);
		}
		else {
			fprintf(stdout, "%d,", compass[i]);
		}
	}

	fprintf(stdout, "]");
}

int main(int argc, char* argv[])
{
	if (argc == 1) {
		fprintf(stderr, "usage: ./prog mapx mapy x1 y1 x2 y2");
		return -1;
	}
	int x, y;
	my_t x1, y1, x2, y2;
	mapx = atol(argv[1]);
	mapy = atol(argv[2]);

	x = atoi(argv[3]);
	y = atoi(argv[4]);
	y = height - y - 1;
	x1 = 2 * (x - width*0.5) / width * ORTHO;
	y1 = 2 * (y - height*0.5) / height * ORTHO;


	x = atoi(argv[5]);
	y = atoi(argv[6]);
	y = height - y - 1;
	x2 = 2 * (x - width*0.5) / width * ORTHO;
	y2 = 2 * (y - height*0.5) / height * ORTHO;

	initialize();
	ga.bnum = bnum;
	ga.fnum = fnum;
	printf("[");

	ga.x1 = x1;
	ga.y1 = y1;
	ga.x2 = x2;
	ga.y2 = y2;
	signalCalcWithCuda();
	convertToCompass();
	printOutput();
	printf(",");

	ga.x1 = x2;
	ga.y1 = y2;
	ga.x2 = x1;
	ga.y2 = y1;
	signalCalcWithCuda();
	convertToCompass();
	printOutput();
	printf("]");


	clean_up();

	return 0;
}

void initialize() {
	load_file();
	allocateCudaMemory();
}

void load_file() {
	int i, count;
	FILE * fp;
	char stmp[255];
	char *pstr;
	char *token;
	char *next_ptr;
	char *c;
	int nidx, bidx, fidx;

	int firstline = True;
	int isname = True;
	int ti;
	int tokidx;
	my_t mxx, mxy, mix, miy;

	fp = fopen("gamemap.txt", "rt");
	if (fp != NULL)
	{
		nidx = bidx = fidx = 0;
		fscanf(fp, "i\t%d\t%d\t%d\t%lld\t%lld\n", &nnum, &bnum, &fnum, &mapx, &mapy);
		Nodes = (node*)malloc(sizeof(node)*nnum);
		Buildings = (polygon*)malloc(sizeof(polygon)*bnum);
		Forests = (polygon*)malloc(sizeof(polygon)*fnum);

		while (!feof(fp))
		{
			pstr = fgets(stmp, sizeof(stmp), fp);
			if (pstr == NULL) break;
			if (pstr[0] == 'n') {
				double lat, lon;
				sscanf(pstr, "n\t%lf\t%lf", &lat, &lon);
				Nodes[nidx].x = (my_t)(lon*1e7 - mapx);
				Nodes[nidx].y = (my_t)(lat*1e7 - mapy);
				nidx++;
			}
			if (*pstr == 'b') {
				count = 0; //except name tag
				for (c = pstr+2; *c != NULL; c++) {
					if (*c == '\t') count++;
				}

				//Buildings[bidx].inodes = (int*)malloc(sizeof(int)*count);
				Buildings[bidx].isize = count;
				mxx = mxy = -99999;
				mix = miy = 99999;

				tokidx = 0;
				isname = True;

				/* get the first token */
				token = strtok(pstr + 2, DELIM);

				/* walk through other tokens */
				while( token != NULL )
				{
					if (isname) {
						isname = False;
						token = strtok(NULL, DELIM);
						continue;
					}
					sscanf(token, "%d", &ti);

					Buildings[bidx].inodes[tokidx] = ti;
					if (mxx < Nodes[ti].x)
						mxx = Nodes[ti].x;
					if (mxy < Nodes[ti].y)
						mxy = Nodes[ti].y;
					if (mix > Nodes[ti].x)
						mix = Nodes[ti].x;
					if (miy > Nodes[ti].y)
						miy = Nodes[ti].y;

					token = strtok(NULL, DELIM);
					tokidx++;
				}

				Buildings[bidx].x = (mxx + mix) / 2;
				Buildings[bidx].y = (mxy + miy) / 2;
				Buildings[bidx].radius = sqrtl((long double)((mxx - mix)*(mxx - mix) + (mxy - miy)*(mxy - miy))) / 2;

				bidx++;
			}
			if (*pstr == 'f') {
				count = 0;
				for (c = pstr+2; *c != NULL; c++) {
					if (*c == '\t') count++;
				}

				//Forests[fidx].inodes = (int*)malloc(sizeof(int)*count);
				Forests[fidx].isize = count;
				mxx = mxy = -99999;
				mix = miy = 99999;

				tokidx = 0;
				isname = True;

				/* get the first token */
				token = strtok(pstr + 2, DELIM);

				/* walk through other tokens */
				while( token != NULL )
				{
					if (isname) {
						isname = False;
						token = strtok(NULL, DELIM);
						continue;
					}
					sscanf(token, "%d", &ti);

					Forests[fidx].inodes[tokidx] = ti;
					if (mxx < Nodes[ti].x)
						mxx = Nodes[ti].x;
					if (mxy < Nodes[ti].y)
						mxy = Nodes[ti].y;
					if (mix > Nodes[ti].x)
						mix = Nodes[ti].x;
					if (miy > Nodes[ti].y)
						miy = Nodes[ti].y;

					token = strtok(NULL, DELIM);
					tokidx++;
				}

				Forests[fidx].x = (mxx + mix) / 2;
				Forests[fidx].y = (mxy + miy) / 2;
				Forests[fidx].radius = sqrtl((long double)((mxx - mix)*(mxx - mix) + (mxy - miy)*(mxy - miy))) / 2;

				fidx++;
			}
		}
		fclose(fp);
	}
	else
	{
		//fprintf(stderr, "File closed\n");
		//file not exist
	}
}

void clean_up() {
	int i;
	free(Nodes);
	free(Buildings);
	free(Forests);

	freeCudaMemory();
}
