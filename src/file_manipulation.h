#ifndef FILE_MANIPULATION_H_
#define FILE_MANIPULATION_H_

#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include <time.h>

char* read_file(char *fileName);
int write_file(char *file_name, char* output_str);
int generate_file(int size);

#endif