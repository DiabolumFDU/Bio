#include "ydma.h"

int main()
{
	ylog("Hello, world!\n");
	int rc;
	off_t offset;
	int value;
	Ydma_Device dma_device;
	ifstream fin;
	ofstream fout;
	char* buf4write = NULL;
	char* buf4read = NULL;

	fin.open("test_bench/reg.txt");
	if (!fin.is_open()) FATAL;
	
	offset = 0;
	while(!fin.eof())
	{
		fin >> hex >> value;
		//ylog("%x\n", value);

		dma_device.Write_Reg(offset*4, value);
		//ylog("%x\n", dma_device.Read_Reg(offset*4));

		offset++;
	}

	ylog("cnt = %d\n", rc);
	fin.close();



	//send_pr
	fin.open("test_bench/pr.bin", ios_base::binary);
	if (!fin.is_open()) FATAL;
	fin.seekg(0, ios::end);
	int fsize = fin.tellg();
	ylog("size of pr.bin: %d bytes\n", fsize);
	fin.seekg(0, ios::beg);
	posix_memalign((void**) &buf4write, 4096, fsize+4096);
	assert(buf4write);
	fin.read(buf4write, fsize);
	fin.close();
	dma_device.Write_DDR(buf4write, fsize, 0);
	free(buf4write);

	//send_spec
	fin.open("test_bench/spec.bin", ios_base::binary);
	if (!fin.is_open()) FATAL;
	fin.seekg(0, ios::end);
	fsize = fin.tellg();
	ylog("size of spec.bin: %d bytes\n", fsize);
	fin.seekg(0, ios::beg);
	posix_memalign((void**) &buf4write, 4096, fsize+4096);
	assert(buf4write);
	fin.read(buf4write, fsize);
	fin.close();
	dma_device.Write_Strm(buf4write, fsize);
	free(buf4write);

	//read_result
	fout.open("result/result.bin", ios_base::binary);
	if (!fout.is_open()) FATAL;
	posix_memalign((void**) &buf4read, 4096, MAX_SIZE+4096);
	assert(buf4read);
	rc = dma_device.Read_Strm(buf4read, MAX_SIZE);
	ylog("PackageNum: %d\n", dma_device.Read_Reg(0x38));
	value = dma_device.Read_Reg(0x38);
	if(rc > (128*(value-1)))
		ylog("All package recieved\n");
	else
	{
		ylog("One more package to recieve\n");
		rc = dma_device.Read_Strm(buf4read + rc, MAX_SIZE);
	}
	fout.write(buf4read, rc);
	fout.close();
	free(buf4read);


	return 0;
}


#if 0

	dma_device.Write_Reg(0x0000, 0x0311);
	dma_device.Write_Reg(0x1000, 0x1993);
	ylog("Read from 0x1008: 0x%x\n", dma_device.Read_Reg(0x1008));
	ylog("Read from 0x0008: 0x%x\n", dma_device.Read_Reg(0x0008));
//--------------------------------------------------------------------------
	char* buf4write = (char*) malloc(LENGTH*sizeof(char));
	char* buf4read = (char*) malloc(LENGTH*sizeof(char));
	int i,j;
	for(i=0;i<LENGTH;i++){
		*(buf4write+i) = i;
	}

	ylog("write:\n");
	for(i=0;i<20;i++){
		ylog("%d,",*(buf4write+i));
	}
	ylog("\n");
	
	ylog("read:\n");
	for(i=0;i<20;i++){
		ylog("%d,",*(buf4read+i));
	}
	ylog("\n");

	dma_device.Write_Strm(buf4write, LENGTH);
	dma_device.Read_Strm(buf4read, LENGTH);

	ylog("read after flow:\n");
	for(i=0;i<20;i++){
		ylog("%d,",*(buf4read+i));
	}
	ylog("\n");
//--------------------------------------------------------------------------
	fin.open("test_bench/pr.bin", ios_base::binary);
	if (!fin.is_open()) FATAL;

	fout.open("result/test_ddr.txt", ios_base::binary);
	if (!fout.is_open()) FATAL;

	fin.seekg(0, ios::end);
	int fsize = fin.tellg();
	ylog("size of pr.bin: %d bytes\n", fsize);
	fin.seekg(0, ios::beg);

	char* buf4write = NULL;
	char* buf4read = NULL;

	posix_memalign((void**) &buf4write, 4096, fsize+4096);
	posix_memalign((void**) &buf4read, 4096, fsize+4096);
	assert(buf4write);

	fin.read(buf4write, fsize);

	dma_device.Write_DDR(buf4write, fsize, 0);
	dma_device.Read_DDR(buf4read, fsize, 0);

	fout.write(buf4read, fsize);

	fin.close();
	fout.close();
#endif
