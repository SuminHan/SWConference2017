# -*- coding: utf-8 -*-
"""
@author: Sumin Han
"""

from bs4 import BeautifulSoup  # HTML parsing library
from lxml import html
import sys
import urllib
import os

lat = float(sys.argv[1])
lon = float(sys.argv[2])

mapx = int(lon * 1e7)
mapy = int(lat * 1e7)

lat = mapy / 1e7
lon = mapx / 1e7

bx1 = str(lon - 0.008)
by1 = str(lat - 0.008)
bx2 = str(lon + 0.012)
by2 = str(lat + 0.010)

mypath = './map_cache'
if not os.path.exists(mypath):
	os.system("mkdir " + mypath)

onlyfiles = [f for f in os.listdir(mypath) if os.path.isfile(os.path.join(mypath, f))]
cache_name = str(mapx) + '.' + str(mapy)
cache_success = [False, False]
for fname in onlyfiles:
	if fname == cache_name + '.osm':
		os.system('cp -f ' + mypath + '/' + cache_name + '.osm ' + 'mymap.osm')
		cache_success[0] = True
		print "[python] cache success: mymap.osm"
		break

for fname in onlyfiles:
	if fname == cache_name + '.txt':
		os.system('cp -f ' + mypath + '/' + cache_name + '.txt ' + 'gamemap.txt')
		cache_success[1] = True
		print "[python] cache success: gamemap.txt"
		break

if cache_success[0] and cache_success[1]:
	sys.exit()

if not cache_success[0]:
	os.system('rm -f mymap.osm');
	urllib.urlretrieve ("http://api.openstreetmap.org/api/0.6/map?bbox="\
		+ bx1 + ',' + by1 + ',' + bx2 + ',' + by2, "mymap.osm")
	os.system('cp -f mymap.osm ' + mypath + '/' + cache_name + '.osm')
	print "[python] download complete: mymap.osm"


if not cache_success[1]:
	os.system('rm -f gamemap.txt');
	nf = open(mypath + '/' + cache_name + '.txt', 'w')  # open text file to write output

	with open(mypath + '/' + cache_name + '.osm', 'rt') as f:  # open html file to read data
		page = f.read()

	# soup = BeautifulSoup(page)
	soup = BeautifulSoup(page, "lxml")
	nodes = soup('node', {})  # save the name of tracks only from whole html file data
	ways = soup('way', {})

	node_list = []
	node_reindex = []
	buildings = []
	forests = []
	amenities = []
	water = []
	roads = []

	idx = 0;
	usedidx = 0;
	for n in nodes:
		node_list += [(idx, n['id'], n['lat'], n['lon'])]
		idx += 1


	def search(mid):
		global node_reindex, usedidx
		for (idx, nid, nlat, nlon) in node_list:
			if (mid == nid):
				if len(node_reindex) > 0:
					for (ridx, pidx, mlat, mlon) in node_reindex:
						if (idx == pidx):
							return ridx
				node_reindex += [(usedidx, idx, nlat, nlon)];
				usedidx += 1
				return usedidx - 1
		return -1


	bnum = 0
	fnum = 0
	anum = 0
	wnum = 0
	rnum = 0
	for w in ways:
		isBuild = False
		isForest = False
		isAmenity = False
		isWater = False
		isRoad = False
		bname = '_'
		for t in w.select("tag"):
			k = t['k']
			v = t['v']
			if k == 'building':
				isBuild = True
				bnum += 1
				break
			if k == 'natural' and v == 'wood':
				fnum += 1
				isForest = True
				break
			if k == 'amenity' and v == 'university':
				isAmenity = True
				anum += 1
				break
			if (k == 'natural' and v == 'water') or (k == 'waterway' and v == 'riverbank'):
				isWater = True
				wnum += 1
				break
			if k == 'highway':
				# if k == 'highway':
				# if k == 'bicycle' and v == 'yes':
				isRoad = True
				rnum += 1
				break

		if isBuild:
			if not w.find("nd"): continue
			if len(w.select("nd")) <= 1: continue
			tmpstr = "b " + bname
			for nd in w.select("nd"):
				kk = search(nd['ref'])
				tmpstr = tmpstr + "\t" + str(kk);
			tmpstr = tmpstr + "\n"
			buildings += [tmpstr]

		if isForest:
			if not w.find("nd"): continue
			tmpstr = "f " + bname
			for nd in w.select("nd"):
				kk = search(nd['ref'])
				tmpstr = tmpstr + "\t" + str(kk);
			tmpstr = tmpstr + "\n"
			forests += [tmpstr]

		if isAmenity:
			if not w.find("nd"): continue
			tmpstr = "a " + bname
			for nd in w.select("nd"):
				kk = search(nd['ref'])
				tmpstr = tmpstr + "\t" + str(kk);
			tmpstr = tmpstr + "\n"
			amenities += [tmpstr]

		if isWater:
			if not w.find("nd"): continue
			tmpstr = "w " + bname
			for nd in w.select("nd"):
				kk = search(nd['ref'])
				tmpstr = tmpstr + "\t" + str(kk);
			tmpstr = tmpstr + "\n"
			water += [tmpstr]

		if isRoad:
			if not w.find("nd"): continue
			tmpstr = "r " + bname
			for nd in w.select("nd"):
				kk = search(nd['ref'])
				tmpstr = tmpstr + "\t" + str(kk);
			tmpstr = tmpstr + "\n"
			roads += [tmpstr]

	print "[python] N_", len(node_list), "=>", len(node_reindex), "B_", len(buildings), "F_", len(forests), \
				"A_", len(amenities), "W_", len(water), "R_", len(roads)
	nf.write(
		"i\t" + str(len(node_reindex)) + "\t" + str(len(buildings)) + "\t" + str(len(forests)) + "\t" + str(mapx) + "\t" +
		str(mapy) + "\n")
	nf.write("# nodes\n")
	for (ridx, idx, mlat, mlon) in node_reindex:
		nf.write("n\t" + str(mlat) + "\t" + str(mlon) + "\n")
	nf.write("# buildings\n")
	for btext in buildings:
		nf.write(btext)
	nf.write("# forests\n")
	for ftext in forests:
		nf.write(ftext)
	nf.write("# amenities\n")
	for ftext in amenities:
		nf.write(ftext)
	nf.write("# water\n")
	for ftext in water:
		nf.write(ftext)
	nf.write("# roads\n")
	for ftext in roads:
		nf.write(ftext)
	nf.close()

	os.system('cp -f ' + mypath + '/' + cache_name + '.txt gamemap.txt')
	print "[python] created cache: gamemap.txt."
