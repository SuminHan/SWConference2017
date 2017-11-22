
with open("MapData.txt") as fr:
	with open("_MapData.txt", "w") as fw:
		for line in fr:
			line = line.strip()
			if line[0] in ['b', 'f']:
				sp = line.split('\t')
				line = line[0] + ' _\t'
				line += '\t'.join(sp[1:])
				fw.write(line + '\n')
			else:
				fw.write(line + '\n')
