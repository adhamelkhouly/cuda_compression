#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#include<ctype.h>
#include <unistd.h>
#include "shell.h"
#include "sequential/rlc.h"

// Prints command list and their descriptions
void help() {
    printf("COMMAND\t\t\tDESCRIPTION\n\n");
    printf("help\t\t\tDisplay all the commands\n");
    printf("quit\t\t\tExits / terminates the shell with “Bye!”\n");
    printf("run SCRIPT.TXT\t\tExecutes the file SCRIPT.TXT\n");
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

    if (words[0] == NULL) // To catch users pressing enter
        return 0;

    else if (strcmp(words[0], "run") == 0){
        if (words[1] != NULL)
            errCode = run(words);
        else
            errCode = 8;
    }
    else if (strcmp(words[0], "srlc") == 0){
        if (words[1] != NULL)
            rlc(words[1]);
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