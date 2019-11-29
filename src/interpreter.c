#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include <stdint.h>
#include<ctype.h>
#include <unistd.h>
#include "shell.h"
#include "sequential/rlc.h"
#include "sequential/huffman.h"
#include "sequential/lzw.h"
#include "file_manipulation.h"

// Prints command list and their descriptions
void help() {
    printf("COMMAND\t\t\t\tDESCRIPTION\n\n");
    printf("help\t\t\t\tDisplay all the commands\n");
    printf("rlc in.txt out.txt\t\tCompresses a file using RLC\n");
    printf("huff in.txt out.txt\t\tCompresses a file using HC\n");
    printf("lzw in.txt out.txt\t\tCompresses a file using LZW\n");
    printf("rlc in.txt out.txt\t\tCompresses a file using RLC\n");
    printf("genfile N\t\t\tCreateas a random file of size N\n");
    printf("run SCRIPT.TXT\t\t\tExecutes the file SCRIPT.TXT\n");
}

// Terminates the shell
void quit() {
    printf("Bye!\n");
    exit(0);
}

int run(char *words[]) {
    int errCode = 0;
    char line[1000];

    FILE *p = fopen(words[1], "r");

    if(p==NULL){ // If file does not exist
        return 9;
	}

    fgets(line,sizeof(line),p);
    while(!feof(p)) {
        char* ret = fgets(line,sizeof(line),p);
        if (ret == NULL){
            break;
        }
        line[strcspn(line, "\n")] = '\0';  // Removing trailing \n due to fgets
        line[strcspn(line, "\r")] = '\0';
        errCode = parseInput(line);
        if (errCode != 0) {
            fclose(p);
            return errCode;
        }
        memset(line, '\0', 1000);
        
    }
    fclose(p);
    return 0;
}

int interpreter(char *words[]) { 
    int errCode = 0;
    char* encoded;
    uint8_t * h_encoded;
    char* input_str;

    if (words[0] == NULL) // To catch users pressing enter
        return 0;

    else if (strcmp(words[0], "run") == 0){
        if (words[1] != NULL)
            errCode = run(words);
        else
            errCode = 8;
    }
    else if (strcmp(words[0], "rlc") == 0){
        if (words[1] != NULL && words[2] != NULL) {
            input_str = read_file(words[1]);
            encoded = rlc(input_str);
            errCode = write_file(words[2], encoded);
            compare_file_size(words[1], words[2]);
        }
        else
            errCode = 8;
    }
    else if (strcmp(words[0], "huff") == 0){
        if (words[1] != NULL && words[2] != NULL) {
            input_str = read_file(words[1]);
            h_encoded = huffman(input_str);
        }
        else
            errCode = 8;
    }
    else if (strcmp(words[0], "lzw") == 0){
        if (words[1] != NULL && words[2] != NULL) {
            errCode = lzw(words[1], words[2]);
            compare_file_size(words[1], "out_lzw.txt");
        }
        else
            errCode = 8;
    }
    else if (strcmp(words[0], "genfile") == 0){
        if (words[1] != NULL) {
            int x;
            generate_file(sscanf(words[1], "%d", &x));
        }
        else
            errCode = 8;
    }
    else if (strcmp(words[0], "help") == 0) {
        if (words[1] != NULL && words[1][0] != '\0')
            errCode = 6;
        else
            help();
    }
    else if (strcmp(words[0], "quit") == 0) {
        if (words[1] != NULL && words[1][0] != '\0') {
            return 7;
        }
        quit();
        
    }
    
    else {
        errCode = 1;
    }
     
    return errCode;
}