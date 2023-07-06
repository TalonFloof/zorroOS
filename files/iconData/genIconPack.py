import json, os

inf = open("IconPack.json","r")
data = json.load(inf)
inf.close()
outf = open("../../root/System/Icons/IconPack","wb")
#typedef struct {
#  uint32_t entrySize;
#  uint16_t width;
#  uint16_t height;
#  uint16_t bpp;
#  uint16_t reserved;
#  uint32_t iconOffset;
#  char name[];
#} IconEntry;
total = 0
for i in data.keys():
	nameSize = (len(i)+(4-(len(i)%4))) if (len(i)+1) % 4 != 0 else (len(i)+1)
	total = total + (16+nameSize)
offset = total + 4
for i in data.keys():
	nameSize = (len(i)+(4-(len(i)%4))) if (len(i)+1) % 4 != 0 else (len(i)+1)
	outf.write(int(16+nameSize).to_bytes(4,'little'))
	outf.write(int(data[i]["width"]).to_bytes(2,'little'))
	outf.write(int(data[i]["height"]).to_bytes(2,'little'))
	outf.write(int(data[i]["bpp"]).to_bytes(2,'little'))
	outf.write(int(0).to_bytes(2,'little'))
	outf.write(int(offset).to_bytes(4,'little'))
	outf.write(i.encode("ASCII"))
	outf.write(int(0).to_bytes(nameSize-len(i),'little'))
	offset = offset + os.stat(data[i]["file"]).st_size
outf.write(int(0).to_bytes(4,'little'))
for i in data.keys():
	binary = open(data[i]["file"],"rb")
	outf.write(binary.read(None))
	binary.close()
outf.close()
